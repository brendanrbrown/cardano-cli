{-# LANGUAGE CPP #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.CLI.EraBased.Run.Address
  ( runAddressBuildCmd
  , runAddressKeyGenCmd
  , runAddressKeyHashCmd
  ) where

import           Cardano.Api
import           Cardano.Api.Shelley

import           Cardano.CLI.Read
import           Cardano.CLI.Types.Key (PaymentVerifier (..), StakeIdentifier (..),
                   StakeVerifier (..), VerificationKeyTextOrFile, generateKeyPair, readVerificationKeyOrFile,
                   readVerificationKeyTextOrFileAnyOf)
import           Cardano.CLI.Types.Common
import           Cardano.CLI.Types.Errors.ShelleyAddressCmdError

import           Control.Monad.IO.Class (MonadIO (..))
import           Control.Monad.Trans.Except (ExceptT)
import           Control.Monad.Trans.Except.Extra (firstExceptT, left, newExceptT)
import qualified Data.ByteString.Char8 as BS
import qualified Data.Text.IO as Text

runAddressKeyGenCmd
  :: KeyOutputFormat
  -> AddressKeyType
  -> VerificationKeyFile Out
  -> SigningKeyFile Out
  -> ExceptT ShelleyAddressCmdError IO ()
runAddressKeyGenCmd fmt kt vkf skf = case kt of
  AddressKeyShelley         -> generateAndWriteKeyFiles fmt  AsPaymentKey          vkf skf
  AddressKeyShelleyExtended -> generateAndWriteKeyFiles fmt  AsPaymentExtendedKey  vkf skf
  AddressKeyByron           -> generateAndWriteByronKeyFiles AsByronKey            vkf skf

generateAndWriteByronKeyFiles
  :: Key keyrole
#if __GLASGOW_HASKELL__ >= 904
-- GHC 8.10 considers the HasTypeProxy constraint redundant but ghc-9.4 and above complains if its
-- not present.
  => HasTypeProxy keyrole
#endif
  => AsType keyrole
  -> VerificationKeyFile Out
  -> SigningKeyFile Out
  -> ExceptT ShelleyAddressCmdError IO ()
generateAndWriteByronKeyFiles asType vkf skf = do
  uncurry (writeByronPaymentKeyFiles vkf skf) =<< liftIO (generateKeyPair asType)

generateAndWriteKeyFiles
  :: Key keyrole
#if __GLASGOW_HASKELL__ >= 904
-- GHC 8.10 considers the HasTypeProxy constraint redundant but ghc-9.4 and above complains if its
-- not present.
  => HasTypeProxy keyrole
#endif
  => SerialiseAsBech32 (SigningKey keyrole)
  => SerialiseAsBech32 (VerificationKey keyrole)
  => KeyOutputFormat
  -> AsType keyrole
  -> VerificationKeyFile Out
  -> SigningKeyFile Out
  -> ExceptT ShelleyAddressCmdError IO ()
generateAndWriteKeyFiles fmt asType vkf skf = do
  uncurry (writePaymentKeyFiles fmt vkf skf) =<< liftIO (generateKeyPair asType)

writePaymentKeyFiles
  :: Key keyrole
  => SerialiseAsBech32 (SigningKey keyrole)
  => SerialiseAsBech32 (VerificationKey keyrole)
  => KeyOutputFormat
  -> VerificationKeyFile Out
  -> SigningKeyFile Out
  -> VerificationKey keyrole
  -> SigningKey keyrole
  -> ExceptT ShelleyAddressCmdError IO ()
writePaymentKeyFiles fmt vkeyPath skeyPath vkey skey = do
  firstExceptT ShelleyAddressCmdWriteFileError $ do
    case fmt of
      KeyOutputFormatTextEnvelope ->
        newExceptT
          $ writeLazyByteStringFile skeyPath
          $ textEnvelopeToJSON (Just skeyDesc) skey
      KeyOutputFormatBech32 ->
        newExceptT
          $ writeTextFile skeyPath
          $ serialiseToBech32 skey

    case fmt of
      KeyOutputFormatTextEnvelope ->
        newExceptT
          $ writeLazyByteStringFile vkeyPath
          $ textEnvelopeToJSON (Just vkeyDesc) vkey
      KeyOutputFormatBech32 ->
        newExceptT
          $ writeTextFile vkeyPath
          $ serialiseToBech32 vkey

  where
    skeyDesc, vkeyDesc :: TextEnvelopeDescr
    skeyDesc = "Payment Signing Key"
    vkeyDesc = "Payment Verification Key"

writeByronPaymentKeyFiles
   :: Key keyrole
   => VerificationKeyFile Out
   -> SigningKeyFile Out
   -> VerificationKey keyrole
   -> SigningKey keyrole
   -> ExceptT ShelleyAddressCmdError IO ()
writeByronPaymentKeyFiles vkeyPath skeyPath vkey skey = do
  firstExceptT ShelleyAddressCmdWriteFileError $ do
    -- No bech32 encoding for Byron keys
    newExceptT $ writeLazyByteStringFile skeyPath $ textEnvelopeToJSON (Just skeyDesc) skey
    newExceptT $ writeLazyByteStringFile vkeyPath $ textEnvelopeToJSON (Just vkeyDesc) vkey
  where
    skeyDesc, vkeyDesc :: TextEnvelopeDescr
    skeyDesc = "Payment Signing Key"
    vkeyDesc = "Payment Verification Key"

runAddressKeyHashCmd :: VerificationKeyTextOrFile
                  -> Maybe (File () Out)
                  -> ExceptT ShelleyAddressCmdError IO ()
runAddressKeyHashCmd vkeyTextOrFile mOutputFp = do
  vkey <- firstExceptT ShelleyAddressCmdVerificationKeyTextOrFileError $
             newExceptT $ readVerificationKeyTextOrFileAnyOf vkeyTextOrFile

  let hexKeyHash = foldSomeAddressVerificationKey
                     (serialiseToRawBytesHex . verificationKeyHash) vkey

  case mOutputFp of
    Just (File fpath) -> liftIO $ BS.writeFile fpath hexKeyHash
    Nothing -> liftIO $ BS.putStrLn hexKeyHash


runAddressBuildCmd :: PaymentVerifier
                -> Maybe StakeIdentifier
                -> NetworkId
                -> Maybe (File () Out)
                -> ExceptT ShelleyAddressCmdError IO ()
runAddressBuildCmd paymentVerifier mbStakeVerifier nw mOutFp = do
  outText <- case paymentVerifier of
    PaymentVerifierKey payVkeyTextOrFile -> do
      payVKey <- firstExceptT ShelleyAddressCmdVerificationKeyTextOrFileError $
         newExceptT $ readVerificationKeyTextOrFileAnyOf payVkeyTextOrFile

      addr <- case payVKey of
        AByronVerificationKey vk ->
          return (AddressByron (makeByronAddress nw vk))

        APaymentVerificationKey vk ->
          AddressShelley <$> buildShelleyAddress vk mbStakeVerifier nw

        APaymentExtendedVerificationKey vk ->
          AddressShelley <$> buildShelleyAddress (castVerificationKey vk) mbStakeVerifier nw

        AGenesisUTxOVerificationKey vk ->
          AddressShelley <$> buildShelleyAddress (castVerificationKey vk) mbStakeVerifier nw
        nonPaymentKey ->
          left $ ShelleyAddressCmdExpectedPaymentVerificationKey nonPaymentKey
      return $ serialiseAddress (addr :: AddressAny)

    PaymentVerifierScriptFile (ScriptFile fp) -> do
      ScriptInAnyLang _lang script <-
        firstExceptT ShelleyAddressCmdReadScriptFileError $
          readFileScriptInAnyLang fp

      let payCred = PaymentCredentialByScript (hashScript script)

      stakeAddressReference <- maybe (return NoStakeAddress) makeStakeAddressRef mbStakeVerifier

      return $ serialiseAddress . makeShelleyAddress nw payCred $ stakeAddressReference

  case mOutFp of
    Just (File fpath) -> liftIO $ Text.writeFile fpath outText
    Nothing           -> liftIO $ Text.putStr          outText

makeStakeAddressRef
  :: StakeIdentifier
  -> ExceptT ShelleyAddressCmdError IO StakeAddressReference
makeStakeAddressRef stakeIdentifier =
  case stakeIdentifier of
    StakeIdentifierVerifier stakeVerifier ->
      case stakeVerifier of
        StakeVerifierKey stkVkeyOrFile -> do
          stakeVKey <- firstExceptT ShelleyAddressCmdReadKeyFileError $
            newExceptT $ readVerificationKeyOrFile AsStakeKey stkVkeyOrFile

          return . StakeAddressByValue . StakeCredentialByKey . verificationKeyHash $ stakeVKey

        StakeVerifierScriptFile (ScriptFile fp) -> do
          ScriptInAnyLang _lang script <-
            firstExceptT ShelleyAddressCmdReadScriptFileError $
              readFileScriptInAnyLang fp

          let stakeCred = StakeCredentialByScript (hashScript script)
          return (StakeAddressByValue stakeCred)
    StakeIdentifierAddress stakeAddr ->
        pure $ StakeAddressByValue $ stakeAddressCredential stakeAddr

buildShelleyAddress
  :: VerificationKey PaymentKey
  -> Maybe StakeIdentifier
  -> NetworkId
  -> ExceptT ShelleyAddressCmdError IO (Address ShelleyAddr)
buildShelleyAddress vkey mbStakeVerifier nw =
  makeShelleyAddress nw (PaymentCredentialByKey (verificationKeyHash vkey)) <$> maybe (return NoStakeAddress) makeStakeAddressRef mbStakeVerifier


--
-- Handling the variety of address key types
--


foldSomeAddressVerificationKey :: (forall keyrole. Key keyrole =>
                                   VerificationKey keyrole -> a)
                               -> SomeAddressVerificationKey -> a
foldSomeAddressVerificationKey f (AByronVerificationKey           vk) = f vk
foldSomeAddressVerificationKey f (APaymentVerificationKey         vk) = f vk
foldSomeAddressVerificationKey f (APaymentExtendedVerificationKey vk) = f vk
foldSomeAddressVerificationKey f (AGenesisUTxOVerificationKey     vk) = f vk
foldSomeAddressVerificationKey f (AKesVerificationKey             vk) = f vk
foldSomeAddressVerificationKey f (AGenesisDelegateExtendedVerificationKey vk) = f vk
foldSomeAddressVerificationKey f (AGenesisExtendedVerificationKey vk) = f vk
foldSomeAddressVerificationKey f (AVrfVerificationKey             vk) = f vk
foldSomeAddressVerificationKey f (AStakeVerificationKey           vk) = f vk
foldSomeAddressVerificationKey f (AStakeExtendedVerificationKey   vk) = f vk
