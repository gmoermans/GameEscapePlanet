param([string]$Out)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $Out | Out-Null

function V($x,$y,$z){ ,[double[]]@($x,$y,$z) }
function Add3($a,$b){ V ($a[0]+$b[0]) ($a[1]+$b[1]) ($a[2]+$b[2]) }
function Sub3($a,$b){ V ($a[0]-$b[0]) ($a[1]-$b[1]) ($a[2]-$b[2]) }
function Mul3($a,$s){ V ($a[0]*$s) ($a[1]*$s) ($a[2]*$s) }
function Dot3($a,$b){ $a[0]*$b[0]+$a[1]*$b[1]+$a[2]*$b[2] }
function Cross3($a,$b){ V ($a[1]*$b[2]-$a[2]*$b[1]) ($a[2]*$b[0]-$a[0]*$b[2]) ($a[0]*$b[1]-$a[1]*$b[0]) }
function Norm3($a){ $l=[math]::Sqrt((Dot3 $a $a)); if($l -lt 1e-9){ return (V 0 0 1) }; Mul3 $a (1.0/$l) }

$script:tris = New-Object System.Collections.ArrayList
function Tri($a,$b,$c){ [void]$script:tris.Add(@($a,$b,$c)) }
function TriBoth($a,$b,$c){ Tri $a $b $c; Tri $a $c $b }
function TriOut($a,$b,$c,$center){
  $n = Cross3 (Sub3 $b $a) (Sub3 $c $a)
  $cen = Mul3 (Add3 (Add3 $a $b) $c) (1.0/3)
  if((Dot3 $n (Sub3 $cen $center)) -lt 0){ Tri $a $c $b } else { Tri $a $b $c }
}
function Basis($axis){
  $a = Norm3 $axis
  $h = if([math]::Abs($a[2]) -gt 0.9){ V 1 0 0 } else { V 0 0 1 }
  $u = Norm3 (Cross3 $h $a)
  $v = Cross3 $a $u
  return @($a,$u,$v)
}
# frustum/pyramid along axis from base. r1 = 0 -> pyramid. cap bottom optional.
function Prism($base,$axis,$r0,$r1,$h,$n,$bottom=$true,$rot=0.0){
  $b = Basis $axis; $a=$b[0]; $u=$b[1]; $v=$b[2]
  $top = Add3 $base (Mul3 $a $h)
  $ring0=@(); $ring1=@()
  for($i=0;$i -lt $n;$i++){
    $t = $rot + 2*[math]::PI*$i/$n
    $d = Add3 (Mul3 $u ([math]::Cos($t))) (Mul3 $v ([math]::Sin($t)))
    $ring0 += ,(Add3 $base (Mul3 $d $r0))
    $ring1 += ,(Add3 $top (Mul3 $d $r1))
  }
  for($i=0;$i -lt $n;$i++){
    $j=($i+1)%$n
    if($r1 -le 0.001){ Tri $ring0[$i] $ring0[$j] $top }
    else { Tri $ring0[$i] $ring0[$j] $ring1[$j]; Tri $ring0[$i] $ring1[$j] $ring1[$i] }
    if($bottom){ Tri $base $ring0[$j] $ring0[$i] }
    if($r1 -gt 0.001){ Tri $top $ring1[$i] $ring1[$j] }
  }
}
# flat double-sided blade along a curved path (up + bend along dir)
function Blade($base,$dir,$len,$w0,$bend,$segs=4){
  $d = Norm3 $dir
  $side = Norm3 (Cross3 $d (V 0 0 1))
  $pts=@()
  for($i=0;$i -le $segs;$i++){
    $t=$i/$segs
    $p = Add3 $base (V ($d[0]*$bend*$t*$t*$len) ($d[1]*$bend*$t*$t*$len) ($len*$t))
    $w = $w0*(1-$t)
    $pts += ,@((Add3 $p (Mul3 $side $w)),(Sub3 $p (Mul3 $side $w)))
  }
  for($i=0;$i -lt $segs;$i++){
    $a=$pts[$i][0];$b=$pts[$i][1];$c=$pts[$i+1][1];$e=$pts[$i+1][0]
    TriBoth $a $b $c; TriBoth $a $c $e
  }
}
function Blob($center,$rx,$ry,$rz,$seed,$jit,$sub=1,$flatBottom=$false){
  $rnd = New-Object System.Random($seed)
  $t=(1+[math]::Sqrt(5))/2
  $raw=@((-1,$t,0),(1,$t,0),(-1,-$t,0),(1,-$t,0),(0,-1,$t),(0,1,$t),(0,-1,-$t),(0,1,-$t),($t,0,-1),($t,0,1),(-$t,0,-1),(-$t,0,1))
  $vs=@(); foreach($r in $raw){ $vs += ,(Norm3 (V $r[0] $r[1] $r[2])) }
  $f=@(@(0,11,5),@(0,5,1),@(0,1,7),@(0,7,10),@(0,10,11),@(1,5,9),@(5,11,4),@(11,10,2),@(10,7,6),@(7,1,8),@(3,9,4),@(3,4,2),@(3,2,6),@(3,6,8),@(3,8,9),@(4,9,5),@(2,4,11),@(6,2,10),@(8,6,7),@(9,8,1))
  $faces=@(); foreach($x in $f){ $faces += ,@($vs[$x[0]],$vs[$x[1]],$vs[$x[2]]) }
  for($s=0;$s -lt $sub;$s++){
    $nf=@()
    foreach($q in $faces){
      $m01=Norm3 (Add3 $q[0] $q[1]); $m12=Norm3 (Add3 $q[1] $q[2]); $m20=Norm3 (Add3 $q[2] $q[0])
      $nf += ,@($q[0],$m01,$m20); $nf += ,@($q[1],$m12,$m01); $nf += ,@($q[2],$m20,$m12); $nf += ,@($m01,$m12,$m20)
    }
    $faces=$nf
  }
  # jitter per unique direction (key by rounded coords)
  $cache=@{}
  function J($p){
    $k = "{0:N3},{1:N3},{2:N3}" -f $p[0],$p[1],$p[2]
    if(-not $cache.ContainsKey($k)){ $cache[$k] = 1.0 + ($rnd.NextDouble()*2-1)*$jit }
    $cache[$k]
  }
  foreach($q in $faces){
    $pp=@()
    foreach($p in $q){
      $k=J $p
      $z=$p[2]*$rz*$k
      if($flatBottom -and $z -lt 0){ $z = $z*0.0 }
      $pp += ,(V ($center[0]+$p[0]*$rx*$k) ($center[1]+$p[1]*$ry*$k) ($center[2]+$z))
    }
    TriOut $pp[0] $pp[1] $pp[2] $center
  }
}
function Save($name){
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("o $name")
  $vi=1
  $vl=New-Object System.Text.StringBuilder; $nl=New-Object System.Text.StringBuilder; $fl=New-Object System.Text.StringBuilder
  $ni=1
  foreach($t in $script:tris){
    $n = Norm3 (Cross3 (Sub3 $t[1] $t[0]) (Sub3 $t[2] $t[0]))
    [void]$nl.AppendLine(("vn {0:F4} {1:F4} {2:F4}" -f $n[0],$n[1],$n[2]))
    $idx=@()
    foreach($p in $t){ [void]$vl.AppendLine(("v {0:F3} {1:F3} {2:F3}" -f $p[0],$p[1],$p[2])); $idx += $vi; $vi++ }
    [void]$fl.AppendLine(("f {0}//{3} {1}//{3} {2}//{3}" -f $idx[0],$idx[1],$idx[2],$ni)); $ni++
  }
  $txt = $sb.ToString()+$vl.ToString()+$nl.ToString()+$fl.ToString()
  [System.IO.File]::WriteAllText((Join-Path $Out "$name.obj"),$txt,(New-Object System.Text.UTF8Encoding($false)))
  "{0}: {1} tris" -f $name,$script:tris.Count
  $script:tris.Clear()
}
$Z = V 0 0 1

# ---------------- TREES (base z=0, ~1300-1600 tall) ----------------
# 1 spire tree: tapered hex trunk + stacked crystal pyramids
Prism (V 0 0 0) $Z 45 20 1000 6 $true
$z0=450; $rad=330; foreach($k in 0..3){ Prism (V 0 0 $z0) $Z $rad 0 420 6 $true (0.3*$k); $z0+=230; $rad*=0.72 }
Save 'tree_scifi1'
# 2 antenna tree: thin mast with stacked hex discs and top spike
Prism (V 0 0 0) $Z 35 18 1500 8 $true
$d=@(@(550,380),@(850,300),@(1150,210)); foreach($x in $d){ Prism (V 0 0 $x[0]) $Z ($x[1]) ($x[1]*0.85) 40 6 $true; Prism (V 0 0 ($x[0]+40)) $Z ($x[1]*0.85) ($x[1]*0.2) 90 6 $false }
Save 'tree_scifi2'
# 3 crystal cluster tree: tall central crystal + leaning shards
Prism (V 0 0 0) $Z 60 60 150 6 $true
Prism (V 0 0 150) $Z 130 130 700 6 $false
Prism (V 0 0 850) $Z 130 0 520 6 $false
$ang=@(0,72,144,216,288); $i=0
foreach($a in $ang){ $r=[math]::PI*$a/180; $ax=V ([math]::Cos($r)*0.45) ([math]::Sin($r)*0.45) 1; $b0=V ([math]::Cos($r)*100) ([math]::Sin($r)*100) 20; $L=520+($i%3)*150
  Prism $b0 $ax 60 60 ($L*0.6) 6 $true; Prism (Add3 $b0 (Mul3 (Norm3 $ax) ($L*0.6))) $ax 60 0 ($L*0.4) 6 $false; $i++ }
Save 'tree_scifi3'

# ---------------- ROCKS (~170 high, base z~0) ----------------
Blob (V 0 0 0) 130 110 150 11 0.22 1 $true
Save 'rock_scifi1'
# 2 hex basalt columns
$cols=@(@(0,0,190,55),@(80,40,130,45),@(-70,55,110,45),@(-30,-85,160,50),@(75,-70,90,40))
foreach($c in $cols){ Prism (V $c[0] $c[1] 0) $Z $c[3] ($c[3]*0.9) $c[2] 6 $true; Prism (V $c[0] $c[1] $c[2]) $Z ($c[3]*0.9) ($c[3]*0.35) 25 6 $false }
Save 'rock_scifi2'
# 3 leaning shards
$sh=@(@(0,0,12,200,70),@(70,30,-18,150,55),@(-60,40,22,130,50))
foreach($s in $sh){ $ax=V ([math]::Sin($s[2]*[math]::PI/180)) 0.15 1; $b0=V $s[0] $s[1] 0; Prism $b0 $ax $s[4] ($s[4]*0.5) ($s[3]*0.7) 4 $true; Prism (Add3 $b0 (Mul3 (Norm3 $ax) ($s[3]*0.7))) $ax ($s[4]*0.5) 0 ($s[3]*0.3) 4 $false }
Blob (V 0 0 30) 110 100 35 5 0.2 0 $true
Save 'rock_scifi3'

# ---------------- PLANTS (~250 tall, +-300 wide) ----------------
# 1 fern: radiating curved blades
for($i=0;$i -lt 9;$i++){ $r=2*[math]::PI*$i/9; $dir=V ([math]::Cos($r)) ([math]::Sin($r)) 0; Blade (Mul3 $dir 12) $dir (180+($i%3)*50) 28 (1.1+0.2*($i%2)) 4 }
Save 'plant_scifi1'
# 2 bulb pod: stem + faceted bulb + leaves
Prism (V 0 0 0) $Z 14 9 140 6 $true
Blob (V 0 0 190) 70 70 85 21 0.12 1 $false
for($i=0;$i -lt 4;$i++){ $r=2*[math]::PI*$i/4+0.4; $dir=V ([math]::Cos($r)) ([math]::Sin($r)) 0; Blade (Mul3 $dir 10) $dir 150 24 1.4 3 }
Save 'plant_scifi2'
# 3 spike cluster
$spk=@(@(0,0,260,22),@(40,15,190,18),@(-35,25,210,18),@(15,-45,150,16),@(-45,-20,170,16),@(55,-30,120,14),@(-10,55,140,14),@(30,40,100,12),@(-60,5,110,12))
foreach($s in $spk){ $lean=V ($s[0]*0.004) ($s[1]*0.004) 1; Prism (V $s[0] $s[1] 0) $lean $s[3] 0 $s[2] 5 $true }
Save 'plant_scifi3'

# ---------------- MATTER SOURCES (centered pivot, ~+-100) ----------------
# 1 crystal cluster
$cr=@(@(0,0,0,0,0,1,36,150),@(40,10,0,0.3,0.1,1,26,110),@(-35,25,0,-0.35,0.2,1,28,120),@(10,-45,0,0.1,-0.4,1,22,95),@(-40,-30,0,-0.3,-0.3,1,20,85))
foreach($c in $cr){ $ax=V $c[3] $c[4] $c[5]; $n=Norm3 $ax; $b0=V $c[0] $c[1] -100; $L=$c[7]*0.65*1.2; Prism $b0 $ax $c[6] $c[6] $L 6 $true; Prism (Add3 $b0 (Mul3 $n $L)) $ax $c[6] 0 ($c[7]*0.55) 6 $false }
Save 'mattersource_scifi1'
# 2 floating core: octahedron + orbiting shards
Prism (V 0 0 0) $Z 70 0 95 4 $false 0.785
Prism (V 0 0 0) (V 0 0 -1) 70 0 95 4 $false 0.785
for($i=0;$i -lt 4;$i++){ $r=2*[math]::PI*$i/4; $p=V ([math]::Cos($r)*100) ([math]::Sin($r)*100) (($i%2)*40-20); $ax=V ([math]::Cos($r)*0.3) ([math]::Sin($r)*0.3) 1; Prism $p $ax 14 0 55 4 $true }
Prism (V 0 0 -105) $Z 55 70 25 8 $true
Save 'mattersource_scifi2'
# 3 reactor pod: hex base, dome, fins
Prism (V 0 0 -105) $Z 95 80 40 6 $true
Prism (V 0 0 -65) $Z 80 70 80 6 $false
Blob (V 0 0 15) 70 70 70 31 0.05 1 $false
for($i=0;$i -lt 6;$i++){ $r=2*[math]::PI*$i/6; $dir=V ([math]::Cos($r)) ([math]::Sin($r)) 0; $b0=Add3 (Mul3 $dir 78) (V 0 0 -60); $ax=V ($dir[0]*0.25) ($dir[1]*0.25) 1; Prism $b0 $ax 12 0 150 4 $true }
Save 'mattersource_scifi3'


