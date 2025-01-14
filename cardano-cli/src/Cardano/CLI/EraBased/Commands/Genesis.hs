{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE LambdaCase #-}

module Cardano.CLI.EraBased.Commands.Genesis
  ( GenesisCmds (..)
  , GenesisCreateCmdArgs (..)
  , GenesisCreateCardanoCmdArgs (..)
  , GenesisCreateStakedCmdArgs (..)
  , GenesisKeyGenGenesisCmdArgs (..)
  , GenesisKeyGenDelegateCmdArgs (..)
  , GenesisKeyGenUTxOCmdArgs (..)
  , GenesisVerKeyCmdArgs (..)
  , GenesisTxInCmdArgs (..)
  , GenesisAddrCmdArgs (..)
  , renderGenesisCmds
  ) where

import           Cardano.Api.Shelley

import           Cardano.Chain.Common (BlockCount)
import           Cardano.CLI.Types.Common

import           Data.Text (Text)

data GenesisCmds era
  = GenesisCreate !GenesisCreateCmdArgs
  | GenesisCreateCardano !GenesisCreateCardanoCmdArgs
  | GenesisCreateStaked !GenesisCreateStakedCmdArgs
  | GenesisKeyGenGenesis !GenesisKeyGenGenesisCmdArgs
  | GenesisKeyGenDelegate !GenesisKeyGenDelegateCmdArgs
  | GenesisKeyGenUTxO !GenesisKeyGenUTxOCmdArgs
  | GenesisCmdKeyHash !(VerificationKeyFile In)
  | GenesisVerKey !GenesisVerKeyCmdArgs
  | GenesisTxIn !GenesisTxInCmdArgs
  | GenesisAddr !GenesisAddrCmdArgs
  | GenesisHashFile !GenesisFile
  deriving Show

data GenesisCreateCmdArgs = GenesisCreateCmdArgs
  { keyOutputFormat :: !KeyOutputFormat
  , genesisDir :: !GenesisDir
  , numGenesisKeys :: !Word
  , numUTxOKeys :: !Word
  , mSystemStart :: !(Maybe SystemStart)
  , mSupply :: !(Maybe Lovelace)
  , network :: !NetworkId
  } deriving Show

data GenesisCreateCardanoCmdArgs = GenesisCreateCardanoCmdArgs
  { genesisDir :: !GenesisDir
  , numGenesisKeys :: !Word
  , numUTxOKeys :: !Word
  , mSystemStart :: !(Maybe SystemStart)
  , mSupply :: !(Maybe Lovelace)
  , security :: !BlockCount
  , slotLength :: !Word
  , slotCoeff :: !Rational
  , network :: !NetworkId
  , byronGenesisTemplate :: !FilePath
  , shelleyGenesisTemplate :: !FilePath
  , alonzoGenesisTemplate :: !FilePath
  , conwayGenesisTemplate :: !FilePath
  , mNodeConfigTemplate :: !(Maybe FilePath)
  } deriving Show

data GenesisCreateStakedCmdArgs = GenesisCreateStakedCmdArgs
  { keyOutputFormat :: !KeyOutputFormat
  , genesisDir :: !GenesisDir
  , numGenesisKeys :: !Word
  , numUTxOKeys :: !Word
  , numPools :: !Word
  , numStakeDelegators :: !Word
  , mSystemStart :: !(Maybe SystemStart)
  , mNonDelegatedSupply :: !(Maybe Lovelace)
  , delegatedSupply :: !Lovelace
  , network :: !NetworkId
  , numBulkPoolCredFiles :: !Word
  , numBulkPoolsPerFile :: !Word
  , numStuffedUtxo :: !Word
  , mStakePoolRelaySpecFile :: !(Maybe FilePath) -- ^ Relay specification filepath
  } deriving Show

data GenesisKeyGenGenesisCmdArgs = GenesisKeyGenGenesisCmdArgs
  { verificationKeyPath :: !(VerificationKeyFile Out)
  , signingKeyPath :: !(SigningKeyFile Out)
  } deriving Show

data GenesisKeyGenDelegateCmdArgs = GenesisKeyGenDelegateCmdArgs
  { verificationKeyPath :: !(VerificationKeyFile Out)
  , signingKeyPath :: !(SigningKeyFile Out)
  , opCertCounterPath :: !(OpCertCounterFile Out)
  } deriving Show

data GenesisKeyGenUTxOCmdArgs = GenesisKeyGenUTxOCmdArgs
  { verificationKeyPath :: !(VerificationKeyFile Out)
  , signingKeyPath :: !(SigningKeyFile Out)
  } deriving Show

data GenesisVerKeyCmdArgs = GenesisVerKeyCmdArgs
  { verificationKeyPath :: !(VerificationKeyFile Out)
  , signingKeyPath :: !(SigningKeyFile In)
  } deriving Show

data GenesisTxInCmdArgs = GenesisTxInCmdArgs
  { verificationKeyPath :: !(VerificationKeyFile In)
  , network :: !NetworkId
  , mOutFile :: !(Maybe (File () Out))
  } deriving Show

data GenesisAddrCmdArgs = GenesisAddrCmdArgs
  { verificationKeyPath :: !(VerificationKeyFile In)
  , network :: !NetworkId
  , mOutFile :: !(Maybe (File () Out))
  } deriving Show

renderGenesisCmds :: GenesisCmds era -> Text
renderGenesisCmds = \case
  GenesisCreate {} ->
    "genesis create"
  GenesisCreateCardano {} ->
    "genesis create-cardano"
  GenesisCreateStaked {} ->
    "genesis create-staked"
  GenesisKeyGenGenesis {} ->
    "genesis key-gen-genesis"
  GenesisKeyGenDelegate {} ->
    "genesis key-gen-delegate"
  GenesisKeyGenUTxO {} ->
    "genesis key-gen-utxo"
  GenesisCmdKeyHash {} ->
    "genesis key-hash"
  GenesisVerKey {} ->
    "genesis get-ver-key"
  GenesisTxIn {} ->
    "genesis initial-txin"
  GenesisAddr {} ->
    "genesis initial-addr"
  GenesisHashFile {} ->
    "genesis hash"
