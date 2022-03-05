{ pkgs
, workbench
, profileNix
, run
, trace ? false }:

pkgs.runCommand "workbench-run-analysis-${profileNix.name}"
  { requiredSystemFeatures = [ "benchmark" ];
    nativeBuildInputs = with pkgs.haskellPackages; with pkgs;
      [ bash coreutils gnused jq moreutils nixWrapped workbench.workbench ];
  }
  ''
  echo "analysing run:  ${run}"
  mkdir -p $out/nix-support

  ln -s ${run} $out/run

  args=(
      ${pkgs.lib.optionalString trace "--trace"}
      analyse
      # --filters size-full
      --outdir  $out
      standard
      ${run}
       )
  echo "wb ''${args[*]}" > $out/wb-invocation.sh

  wb ''${args[@]}

  cat > $out/nix-support/hydra-build-products <<EOF
  report block-propagation $out block-propagation.txt
  report node-1-timeline   $out logs-node-1.timeline.txt
  EOF
  ''
