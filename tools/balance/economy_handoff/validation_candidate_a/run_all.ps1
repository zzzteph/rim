$S = "C:\Users\steph\AppData\Local\Temp\claude\c--Users-steph-Documents-GitHub-rim\88d8a41f-2588-413f-a4aa-22b46178ff3c\scratchpad"
$g = "C:\Users\steph\Downloads\godot\Godot_v4.7.2-stable_win64_console.exe"
$out = "$S\econ\out"
$procs = @()
foreach ($rs in @("base", "cand")) {
  foreach ($seed in @(7, 19, 43)) {
    foreach ($pol in @("original", "adapted")) {
      $f = "$out\match_${rs}_${pol}_s$seed.json"
      $procs += Start-Process -FilePath $g -PassThru -WindowStyle Hidden -RedirectStandardOutput "$out\log_match_${rs}_${pol}_s$seed.txt" -RedirectStandardError "$out\err_match_${rs}_${pol}_s$seed.txt" -ArgumentList '--headless','--path',"$S\exp_$rs",'--script',"$S\econ\econ_experiment.gd",'--','--mode','match','--seed',"$seed",'--policy',$pol,'--out',$f
    }
    $f = "$out\fixtures_${rs}_s$seed.json"
    $procs += Start-Process -FilePath $g -PassThru -WindowStyle Hidden -RedirectStandardOutput "$out\log_fx_${rs}_s$seed.txt" -RedirectStandardError "$out\err_fx_${rs}_s$seed.txt" -ArgumentList '--headless','--path',"$S\exp_$rs",'--script',"$S\econ\econ_experiment.gd",'--','--mode','fixtures','--seed',"$seed",'--out',$f
  }
}
$procs | Wait-Process -Timeout 3000
"done: " + ($procs | ForEach-Object { $_.ExitCode }) -join ","
Get-ChildItem "$out\match_*.json", "$out\fixtures_*.json" | Select-Object Name, Length | Format-Table -AutoSize | Out-String
