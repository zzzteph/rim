$S = "C:\Users\steph\AppData\Local\Temp\claude\c--Users-steph-Documents-GitHub-rim\88d8a41f-2588-413f-a4aa-22b46178ff3c\scratchpad"
$g = "C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64_console.exe"
$out = "$S\econ\out"
$procs = @()
function Launch($rs, $mode, $seed, $pol, $f) {
  return Start-Process -FilePath $g -PassThru -WindowStyle Hidden -RedirectStandardOutput "$f.log" -RedirectStandardError "$f.err" -ArgumentList '--headless','--path',"$S\exp_$rs",'--script',"$S\econ\econ_experiment.gd",'--','--mode',$mode,'--seed',"$seed",'--policy',$pol,'--out',$f
}
foreach ($seed in @(7, 19, 43)) {
  foreach ($rs in @("base", "cand", "c20")) { $procs += Launch $rs "fixtures" $seed "adapted" "$out\fixtures_${rs}_s$seed.json" }
  foreach ($pol in @("original", "adapted", "adapted_late")) { $procs += Launch "c20" "match" $seed $pol "$out\match_c20_${pol}_s$seed.json" }
  foreach ($rs in @("base", "cand")) { $procs += Launch $rs "match" $seed "adapted_late" "$out\match_${rs}_adapted_late_s$seed.json" }
}
$procs | Wait-Process -Timeout 3000
"exit codes: " + (($procs | ForEach-Object { $_.ExitCode }) -join ",")
