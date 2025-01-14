{-# LANGUAGE OverloadedStrings #-}

module Test.Golden.Shelley.Genesis.InitialTxIn where

import           Test.Cardano.CLI.Util

import           Hedgehog (Property)
import qualified Hedgehog.Extras.Test.Golden as H

{- HLINT ignore "Use camelCase" -}

hprop_golden_shelleyGenesisInitialTxIn :: Property
hprop_golden_shelleyGenesisInitialTxIn = propertyOnce $ do
  verificationKeyFile <- noteInputFile "test/cardano-cli-golden/files/input/shelley/keys/genesis_verification_keys/genesis-utxo.vkey"
  goldenUtxoHashFile <- noteInputFile "test/cardano-cli-golden/files/golden/shelley/keys/genesis_utxo_hashes/utxo_hash"
  utxoHash <- execCardanoCLI
    [ "genesis","initial-txin"
    , "--testnet-magic", "16"
    , "--verification-key-file", verificationKeyFile
    ]

  H.diffVsGoldenFile utxoHash goldenUtxoHashFile
