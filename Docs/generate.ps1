# Regenerates Docs/code-docs.html from Docs/doc_dump.json (structure exported from the editor)
# and Docs/descriptions.json (hand-written comments). Run:  powershell -File Docs/generate.ps1
$dir  = $PSScriptRoot
$dump = Get-Content "$dir\doc_dump.json" -Raw | ConvertFrom-Json
$desc = Get-Content "$dir\descriptions.json" -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Web
function Esc($s) { [System.Web.HttpUtility]::HtmlEncode([string]$s) }

$groups = [ordered]@{ 'Core' = @(); 'Characters' = @(); 'Tools' = @(); 'Buildables' = @(); 'World' = @(); 'Monsters' = @(); 'UI' = @() }
foreach ($p in $dump.PSObject.Properties) {
  $folder = ($p.Value.path -split '/')[3]
  if (-not $groups.Contains($folder)) { $groups[$folder] = @() }
  $groups[$folder] += $p.Name
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.Append(@'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>PlanetEscape - Blueprint code documentation</title>
<style>
:root{--bg:#fff;--fg:#1d2433;--mut:#66708a;--card:#f5f7fb;--bd:#dde3ee;--acc:#2a6df4;--code:#eef1f8}
@media (prefers-color-scheme:dark){:root{--bg:#10141c;--fg:#e3e8f3;--mut:#93a0bb;--card:#181e2a;--bd:#2a3347;--acc:#7aa5ff;--code:#1f2736}}
body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,Segoe UI,sans-serif;display:flex}
nav{width:270px;flex:none;height:100vh;overflow:auto;position:sticky;top:0;padding:16px;border-right:1px solid var(--bd);box-sizing:border-box}
nav h1{font-size:16px;margin:0 0 8px}nav input{width:100%;box-sizing:border-box;padding:6px 8px;border:1px solid var(--bd);border-radius:6px;background:var(--card);color:var(--fg)}
nav h3{font-size:12px;text-transform:uppercase;letter-spacing:.06em;color:var(--mut);margin:16px 0 4px}
nav a{display:block;padding:2px 0;color:var(--fg);text-decoration:none;font-size:14px}nav a:hover{color:var(--acc)}
main{flex:1;max-width:1000px;padding:24px 32px;box-sizing:border-box;min-width:0}
section.cls{border:1px solid var(--bd);background:var(--card);border-radius:10px;padding:16px 20px;margin:0 0 24px}
section.cls h2{margin:0 0 2px;font-size:20px}.parent{color:var(--mut);font-size:13px;margin-bottom:8px}
h4{margin:16px 0 6px;font-size:13px;text-transform:uppercase;letter-spacing:.05em;color:var(--mut)}
table{border-collapse:collapse;width:100%;font-size:14px}td,th{border-top:1px solid var(--bd);padding:5px 8px;text-align:left;vertical-align:top}
code{background:var(--code);padding:1px 5px;border-radius:4px;font:13px ui-monospace,Consolas,monospace}
.fn td:first-child{white-space:nowrap}.none{color:var(--mut);font-style:italic}.rep{color:var(--acc)}
@media (max-width:800px){body{display:block}nav{width:auto;height:auto;position:static}main{padding:16px}}
</style></head><body>
<nav><h1>PlanetEscape<br><small>Blueprint docs</small></h1><input id="q" placeholder="Filter classes / functions..." oninput="f(this.value)">
'@)
foreach ($g in $groups.Keys) {
  if ($groups[$g].Count -eq 0) { continue }
  [void]$sb.Append("<h3>$(Esc $g)</h3>")
  foreach ($n in $groups[$g]) { [void]$sb.Append("<a href='#$n' data-n='$n'>$(Esc $n)</a>") }
}
[void]$sb.Append("</nav><main><h1>PlanetEscape - Blueprint code documentation</h1><p class='none'>Generated from the editor (classes, variables, functions, events) plus hand-written comments in <code>Docs/descriptions.json</code>. Replication: <span class='rep'>Replicated</span> / <span class='rep'>RepNotify</span>.</p>")
$missing = 0
foreach ($g in $groups.Keys) {
  foreach ($n in $groups[$g]) {
    $c = $dump.$n
    $cd = $desc.classes.$n
    [void]$sb.Append("<section class='cls' id='$n'><h2>$(Esc $n)</h2><div class='parent'>$(Esc $g) &middot; extends <code>$(Esc $c.parent)</code></div>")
    if ($cd) { [void]$sb.Append("<p>$(Esc $cd)</p>") } else { [void]$sb.Append("<p class='none'>(no description)</p>"); $missing++ }
    if ($c.vars.Count -gt 0) {
      [void]$sb.Append("<h4>Variables</h4><table><tr><th>Name</th><th>Category</th><th>Replication</th></tr>")
      foreach ($v in $c.vars) {
        $rep = if ($v[2] -and $v[2] -ne 'None') { "<span class='rep'>$(Esc $v[2])</span>" } else { '' }
        [void]$sb.Append("<tr><td><code>$(Esc $v[0])</code></td><td>$(Esc $v[1])</td><td>$rep</td></tr>")
      }
      [void]$sb.Append("</table>")
    }
    if ($c.fns.Count -gt 0) {
      [void]$sb.Append("<h4>Functions</h4><table class='fn'><tr><th>Signature</th><th>Description</th></tr>")
      foreach ($fn in $c.fns) {
        $name = $fn[0]; $sig = ($fn[1] -replace '^\(fn\s+', '(' ); $sig = $sig -replace '\)\s*$', ')'
        $d = $desc.functions."$n.$name"
        if (-not $d) { $d = "<span class='none'>(no description)</span>"; $missing++ } else { $d = Esc $d }
        [void]$sb.Append("<tr data-s='$($name.ToLower())'><td><code>$(Esc $sig)</code></td><td>$d</td></tr>")
      }
      [void]$sb.Append("</table>")
    }
    if ($c.events.Count -gt 0) {
      [void]$sb.Append("<h4>Events</h4><table><tr><th>Event</th></tr>")
      foreach ($e in $c.events) {
        $ev = $e -replace '^\(event\s+', ''
        [void]$sb.Append("<tr><td><code>" + (Esc $ev) + "</code></td></tr>")
      }
      [void]$sb.Append("</table>")
    }
    [void]$sb.Append("</section>")
  }
}
[void]$sb.Append(@'
</main><script>
function f(t){t=t.toLowerCase();document.querySelectorAll('nav a').forEach(a=>a.style.display=a.dataset.n.toLowerCase().includes(t)||!t?'':'none');
document.querySelectorAll('section.cls').forEach(s=>{let hit=!t||s.id.toLowerCase().includes(t);s.querySelectorAll('tr[data-s]').forEach(r=>{const m=!t||r.dataset.s.includes(t)||r.textContent.toLowerCase().includes(t);r.style.display=m?'':'none';if(m&&t)hit=true});s.style.display=hit?'':'none'})}
</script></body></html>
'@)
[System.IO.File]::WriteAllText("$dir\code-docs.html", $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
"Written $dir\code-docs.html  (missing descriptions: $missing)"
