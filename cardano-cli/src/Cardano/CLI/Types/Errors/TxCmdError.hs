{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.CLI.Types.Errors.TxCmdError
  ( TxCmdError(..)
  , renderTxCmdError
  ) where

import           Cardano.Api
import           Cardano.Api.Shelley

import           Cardano.CLI.Read
import           Cardano.CLI.Types.Common
import           Cardano.CLI.Types.Errors.BootstrapWitnessError
import           Cardano.CLI.Types.Errors.NodeEraMismatchError
import           Cardano.CLI.Types.Errors.ProtocolParamsError
import           Cardano.CLI.Types.Errors.TxValidationError
import           Cardano.CLI.Types.Output
import           Cardano.CLI.Types.TxFeature
import           Ouroboros.Consensus.Cardano.Block (EraMismatch (..))

import           Data.Text (Text)
import qualified Data.Text as Text

{- HLINT ignore "Use let" -}

data TxCmdError
  = TxCmdMetadataError MetadataError
  | TxCmdVoteError VoteError
  | TxCmdConstitutionError ConstitutionError
  | TxCmdScriptWitnessError ScriptWitnessError
  | TxCmdProtocolParamsError ProtocolParamsError
  | TxCmdScriptFileError (FileError ScriptDecodeError)
  | TxCmdReadTextViewFileError !(FileError TextEnvelopeError)
  | TxCmdReadWitnessSigningDataError !ReadWitnessSigningDataError
  | TxCmdWriteFileError !(FileError ())
  | TxCmdBootstrapWitnessError !BootstrapWitnessError
  | TxCmdTxSubmitError !Text
  | TxCmdTxSubmitErrorEraMismatch !EraMismatch
  | TxCmdTxFeatureMismatch !AnyCardanoEra !TxFeature
  | TxCmdTxBodyError !TxBodyError
  | TxCmdNotImplemented !Text
  | TxCmdWitnessEraMismatch !AnyCardanoEra !AnyCardanoEra !WitnessFile
  | TxCmdPolicyIdsMissing ![PolicyId]
  | TxCmdPolicyIdsExcess  ![PolicyId]
  | TxCmdByronEra
  | TxCmdBalanceTxBody !TxBodyErrorAutoBalance
  | TxCmdTxInsDoNotExist !TxInsExistError
  | TxCmdPParamsErr !ProtocolParametersError
  | TxCmdTextEnvCddlError
      !(FileError TextEnvelopeError)
      !(FileError TextEnvelopeCddlError)
  | TxCmdTxExecUnitsErr !TransactionValidityError
  | TxCmdPlutusScriptCostErr !PlutusScriptCostError
  | TxCmdPParamExecutionUnitsNotAvailable
  | TxCmdPlutusScriptsRequireCardanoMode
  | TxCmdProtocolParametersNotPresentInTxBody
  | TxCmdTxNodeEraMismatchError !NodeEraMismatchError
  | TxCmdQueryConvenienceError !QueryConvenienceError
  | TxCmdQueryNotScriptLocked !ScriptLockedTxInsError
  | TxCmdScriptDataError !ScriptDataError
  | TxCmdCddlError CddlError
  | TxCmdCddlWitnessError CddlWitnessError
  | TxCmdRequiredSignerError RequiredSignerError
  -- Validation errors
  | TxCmdAuxScriptsValidationError TxAuxScriptsValidationError
  | TxCmdTotalCollateralValidationError TxTotalCollateralValidationError
  | TxCmdReturnCollateralValidationError TxReturnCollateralValidationError
  | TxCmdTxFeeValidationError TxFeeValidationError
  | TxCmdTxValidityLowerBoundValidationError TxValidityLowerBoundValidationError
  | TxCmdTxValidityUpperBoundValidationError TxValidityUpperBoundValidationError
  | TxCmdRequiredSignersValidationError TxRequiredSignersValidationError
  | TxCmdProtocolParametersValidationError TxProtocolParametersValidationError
  | TxCmdTxWithdrawalsValidationError TxWithdrawalsValidationError
  | TxCmdTxCertificatesValidationError TxCertificatesValidationError
  | TxCmdTxUpdateProposalValidationError TxUpdateProposalValidationError
  | TxCmdScriptValidityValidationError TxScriptValidityValidationError
  | TxCmdProtocolParamsConverstionError ProtocolParametersConversionError

renderTxCmdError :: TxCmdError -> Text
renderTxCmdError err =
  case err of
    TxCmdProtocolParamsConverstionError err' ->
      "Error while converting protocol parameters: " <> Text.pack (displayError err')
    TxCmdVoteError voteErr -> Text.pack $ show voteErr
    TxCmdConstitutionError constErr -> Text.pack $ show constErr
    TxCmdReadTextViewFileError fileErr -> Text.pack (displayError fileErr)
    TxCmdScriptFileError fileErr -> Text.pack (displayError fileErr)
    TxCmdReadWitnessSigningDataError witSignDataErr ->
      renderReadWitnessSigningDataError witSignDataErr
    TxCmdWriteFileError fileErr -> Text.pack (displayError fileErr)
    TxCmdTxSubmitError res -> "Error while submitting tx: " <> res
    TxCmdTxSubmitErrorEraMismatch EraMismatch{ledgerEraName, otherEraName} ->
      "The era of the node and the tx do not match. " <>
      "The node is running in the " <> ledgerEraName <>
      " era, but the transaction is for the " <> otherEraName <> " era."
    TxCmdBootstrapWitnessError sbwErr ->
      renderBootstrapWitnessError sbwErr
    TxCmdTxFeatureMismatch era TxFeatureImplicitFees ->
      "An explicit transaction fee must be specified for " <>
      renderEra era <> " era transactions."

    TxCmdTxFeatureMismatch (AnyCardanoEra ShelleyEra)
                                  TxFeatureValidityNoUpperBound ->
      "A TTL must be specified for Shelley era transactions."

    TxCmdTxFeatureMismatch era feature ->
      renderFeature feature <> " cannot be used for " <> renderEra era <>
      " era transactions."

    TxCmdTxBodyError err' ->
      "Transaction validaton error: " <> Text.pack (displayError err')

    TxCmdNotImplemented msg ->
      "Feature not yet implemented: " <> msg

    TxCmdWitnessEraMismatch era era' (WitnessFile file) ->
      "The era of a witness does not match the era of the transaction. " <>
      "The transaction is for the " <> renderEra era <> " era, but the " <>
      "witness in " <> textShow file <> " is for the " <> renderEra era' <> " era."

    TxCmdPolicyIdsMissing policyids -> mconcat
      [ "The \"--mint\" flag specifies an asset with a policy Id, but no "
      , "corresponding monetary policy script has been provided as a witness "
      , "(via the \"--mint-script-file\" flag). The policy Id in question is: "
      , Text.intercalate ", " (map serialiseToRawBytesHexText policyids)
      ]

    TxCmdPolicyIdsExcess policyids -> mconcat
      [ "A script provided to witness minting does not correspond to the policy "
      , "id of any asset specified in the \"--mint\" field. The script hash is: "
      , Text.intercalate ", " (map serialiseToRawBytesHexText policyids)
      ]
    TxCmdByronEra -> "This query cannot be used for the Byron era"
    TxCmdBalanceTxBody err' -> Text.pack $ displayError err'
    TxCmdTxInsDoNotExist e ->
      renderTxInsExistError e
    TxCmdPParamsErr err' -> Text.pack $ displayError err'
    TxCmdTextEnvCddlError textEnvErr cddlErr -> mconcat
      [ "Failed to decode neither the cli's serialisation format nor the ledger's "
      , "CDDL serialisation format. TextEnvelope error: " <> Text.pack (displayError textEnvErr) <> "\n"
      , "TextEnvelopeCddl error: " <> Text.pack (displayError cddlErr)
      ]
    TxCmdTxExecUnitsErr err' ->  Text.pack $ displayError err'
    TxCmdPlutusScriptCostErr err'-> Text.pack $ displayError err'
    TxCmdPParamExecutionUnitsNotAvailable -> mconcat
      [ "Execution units not available in the protocol parameters. This is "
      , "likely due to not being in the Alonzo era"
      ]
    TxCmdTxNodeEraMismatchError (NodeEraMismatchError nodeEra valueEra) ->
      cardanoEraConstraints nodeEra $ cardanoEraConstraints valueEra $ mconcat
        [ "Transactions can only be produced in the same era as the node. Requested era: "
        , renderEra (AnyCardanoEra valueEra) <> ", node era: "
        , renderEra (AnyCardanoEra nodeEra) <> "."
        ]
    TxCmdQueryConvenienceError e ->
      renderQueryConvenienceError e
    TxCmdQueryNotScriptLocked e ->
      renderNotScriptLockedTxInsError e
    TxCmdPlutusScriptsRequireCardanoMode ->
      "Plutus scripts are only available in CardanoMode"
    TxCmdProtocolParametersNotPresentInTxBody ->
      "Protocol parameters were not found in transaction body"
    TxCmdMetadataError e -> renderMetadataError e
    TxCmdScriptWitnessError e -> renderScriptWitnessError e
    TxCmdScriptDataError e -> renderScriptDataError e
    TxCmdProtocolParamsError e -> renderProtocolParamsError e
    TxCmdCddlError e -> Text.pack $ displayError e
    TxCmdCddlWitnessError e -> Text.pack $ displayError e
    TxCmdRequiredSignerError e -> Text.pack $ displayError e
    -- Validation errors
    TxCmdAuxScriptsValidationError e ->
      Text.pack $ displayError e
    TxCmdTotalCollateralValidationError e ->
      Text.pack $ displayError e
    TxCmdReturnCollateralValidationError e ->
      Text.pack $ displayError e
    TxCmdTxFeeValidationError e ->
      Text.pack $ displayError e
    TxCmdTxValidityLowerBoundValidationError e ->
      Text.pack $ displayError e
    TxCmdTxValidityUpperBoundValidationError e ->
      Text.pack $ displayError e
    TxCmdRequiredSignersValidationError e ->
      Text.pack $ displayError e
    TxCmdProtocolParametersValidationError e ->
      Text.pack $ displayError e
    TxCmdTxWithdrawalsValidationError e ->
      Text.pack $ displayError e
    TxCmdTxCertificatesValidationError e ->
      Text.pack $ displayError e
    TxCmdTxUpdateProposalValidationError e ->
      Text.pack $ displayError e
    TxCmdScriptValidityValidationError e ->
      Text.pack $ displayError e
