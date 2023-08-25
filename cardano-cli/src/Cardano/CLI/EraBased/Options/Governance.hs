{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

module Cardano.CLI.EraBased.Options.Governance
  ( EraBasedGovernanceCmds(..)
  , renderEraBasedGovernanceCmds
  , pEraBasedGovernanceCmds
  ) where

import           Cardano.Api

import           Cardano.CLI.Environment
import           Cardano.CLI.EraBased.Commands.Governance
import           Cardano.CLI.EraBased.Options.Common
import           Cardano.CLI.EraBased.Options.Governance.Actions
import           Cardano.CLI.EraBased.Options.Governance.Committee
import           Cardano.CLI.EraBased.Options.Governance.DRep
import           Cardano.CLI.EraBased.Options.Governance.Vote
import           Cardano.CLI.Types.Common

import           Data.Foldable
import           Data.Maybe
import           Options.Applicative
import qualified Options.Applicative as Opt

pEraBasedGovernanceCmds :: EnvCli -> CardanoEra era -> Parser (EraBasedGovernanceCmds era)
pEraBasedGovernanceCmds envCli era =
  asum $ catMaybes
    [ pCreateMirCertificatesCmds era
    , fmap EraBasedGovernanceActionCmds     <$> pGovernanceActionCmds era
    , fmap EraBasedGovernanceCommitteeCmds  <$> pGovernanceCommitteeCmds era
    , fmap EraBasedGovernanceDRepCmds       <$> pGovernanceDRepCmds envCli era
    , fmap EraBasedGovernanceVoteCmds       <$> pGovernanceVoteCmds era
    ]

--------------------------------------------------------------------------------

-- Vote related


--------------------------------------------------------------------------------


pCreateMirCertificatesCmds :: CardanoEra era -> Maybe (Parser (EraBasedGovernanceCmds era))
pCreateMirCertificatesCmds era = do
  w <- maybeFeatureInEra era
  pure
    $ subParser "create-mir-certificate"
    $ Opt.info (pMIRPayStakeAddresses w <|> mirCertParsers w)
    $ Opt.progDesc "Create an MIR (Move Instantaneous Rewards) certificate"

mirCertParsers :: ()
  => ShelleyToBabbageEra era
  -> Parser (EraBasedGovernanceCmds era)
mirCertParsers w =
  asum
    [ subParser "stake-addresses"
      $ Opt.info (pMIRPayStakeAddresses w)
      $ Opt.progDesc "Create an MIR certificate to pay stake addresses"
    , subParser "transfer-to-treasury"
      $ Opt.info (pMIRTransferToTreasury w)
      $ Opt.progDesc "Create an MIR certificate to transfer from the reserves pot to the treasury pot"
    , subParser "transfer-to-rewards"
      $ Opt.info (pMIRTransferToReserves w)
      $ Opt.progDesc "Create an MIR certificate to transfer from the treasury pot to the reserves pot"
    ]

pMIRPayStakeAddresses :: ()
  => ShelleyToBabbageEra era
  -> Parser (EraBasedGovernanceCmds era)
pMIRPayStakeAddresses w =
  EraBasedGovernanceMIRPayStakeAddressesCertificate w
    <$> pMIRPot
    <*> some pStakeAddress
    <*> some pRewardAmt
    <*> pOutputFile

pMIRTransferToTreasury :: ()
  => ShelleyToBabbageEra era
  -> Parser (EraBasedGovernanceCmds era)
pMIRTransferToTreasury w =
  EraBasedGovernanceMIRTransfer w
    <$> pTransferAmt
    <*> pOutputFile
    <*> pure TransferToTreasury

pMIRTransferToReserves :: ()
  => ShelleyToBabbageEra era
  -> Parser (EraBasedGovernanceCmds era)
pMIRTransferToReserves w =
  EraBasedGovernanceMIRTransfer w
    <$> pTransferAmt
    <*> pOutputFile
    <*> pure TransferToReserves