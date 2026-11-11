param([string]$Out)
New-Item -ItemType Directory -Force $Out | Out-Null
Add-Type -TypeDefinition @"
using System;
using System.IO;
public static class Synth {
  const int SR = 44100;
  static Random rnd = new Random(7);
  public static void Write(string path, float[] d){
    float peak = 0.0001f; foreach (var s in d) peak = Math.Max(peak, Math.Abs(s));
    float g = 0.89f / peak;
    using (var fs = new FileStream(path, FileMode.Create)) using (var w = new BinaryWriter(fs)) {
      int n = d.Length;
      w.Write(new char[]{'R','I','F','F'}); w.Write(36 + n*2); w.Write(new char[]{'W','A','V','E','f','m','t',' '});
      w.Write(16); w.Write((short)1); w.Write((short)1); w.Write(SR); w.Write(SR*2); w.Write((short)2); w.Write((short)16);
      w.Write(new char[]{'d','a','t','a'}); w.Write(n*2);
      foreach (var s in d) w.Write((short)(Math.Max(-1f, Math.Min(1f, s*g))*32767));
    }
  }
  static float[] Buf(double sec){ return new float[(int)(SR*sec)]; }
  static float Noise(){ return (float)(rnd.NextDouble()*2-1); }
  static float Env(int i,int n,double a,double dec){ double t=(double)i/SR; double at = a>0? Math.Min(1.0,t/a):1.0; return (float)(at*Math.Exp(-t*dec)); }
  // laser-like zap / grenade launch thump
  public static float[] Thump(){ var d=Buf(0.55); double ph=0; for(int i=0;i<d.Length;i++){ double t=(double)i/SR; double f=40+160*Math.Exp(-t*18); ph+=2*Math.PI*f/SR; d[i]=(float)(Math.Sin(ph)*Math.Exp(-t*7)+0.35*Noise()*Math.Exp(-t*30)+0.25*Math.Sin(ph*2.01)*Math.Exp(-t*12)); } return d; }
  // plasma explosion (grenade)
  public static float[] Boom(){ var d=Buf(1.4); float lp=0; double ph=0; for(int i=0;i<d.Length;i++){ double t=(double)i/SR; lp+= (Noise()-lp)*(float)(0.04+0.25*Math.Exp(-t*6)); double f=55*Math.Exp(-t*2.5)+20; ph+=2*Math.PI*f/SR; d[i]=(float)(lp*1.8*Math.Exp(-t*2.6)+Math.Sin(ph)*Math.Exp(-t*3.2)+0.3*Noise()*Math.Exp(-t*45)); } return d; }
  // mechanical reload: two clicks + slide
  public static float[] Reload(){ var d=Buf(1.1); double[] ev={0.0,0.18,0.62,0.95}; double[] fr={1800,900,1400,2600};
    for(int k=0;k<ev.Length;k++){ int s0=(int)(ev[k]*SR); for(int i=0;i<(int)(0.12*SR)&&s0+i<d.Length;i++){ double t=(double)i/SR; d[s0+i]+= (float)((Math.Sin(2*Math.PI*fr[k]*t)*0.6+Noise()*0.5)*Math.Exp(-t*55)); } }
    float lp=0; for(int i=(int)(0.25*SR);i<(int)(0.6*SR);i++){ double t=(double)(i-0.25*SR)/SR; lp+=(Noise()-lp)*0.12f; d[i]+=lp*0.35f*(float)Math.Sin(Math.PI*t/0.35); } return d; }
  // sci-fi pickup chime (rising arpeggio)
  public static float[] Pickup(){ var d=Buf(0.7); double[] fr={660,880,1320}; for(int k=0;k<3;k++){ int s0=(int)(k*0.09*SR); for(int i=0;s0+i<d.Length;i++){ double t=(double)i/SR; d[s0+i]+=(float)((Math.Sin(2*Math.PI*fr[k]*t)+0.4*Math.Sin(2*Math.PI*fr[k]*2.0*t))*Math.Exp(-t*7)*0.5); } } return d; }
  // matter drop: descending whoosh + sparkle
  public static float[] Drop(){ var d=Buf(0.8); double ph=0; float lp=0; for(int i=0;i<d.Length;i++){ double t=(double)i/SR; double f=1400*Math.Exp(-t*3.2)+120; ph+=2*Math.PI*f/SR; lp+=(Noise()-lp)*0.08f; d[i]=(float)((Math.Sin(ph)*0.6+lp*0.8)*Math.Sin(Math.PI*Math.Min(1.0,t/0.8))*Math.Exp(-t*1.5)); } return d; }
  // UI click / select
  public static float[] Click(){ var d=Buf(0.12); for(int i=0;i<d.Length;i++){ double t=(double)i/SR; d[i]=(float)((Math.Sin(2*Math.PI*1200*t)+0.5*Math.Sin(2*Math.PI*2400*t))*Math.Exp(-t*45)); } return d; }
  // automatic gun shot (short plasma burst)
  public static float[] Rifle(){ var d=Buf(0.25); double ph=0; for(int i=0;i<d.Length;i++){ double t=(double)i/SR; double f=900*Math.Exp(-t*22)+140; ph+=2*Math.PI*f/SR; d[i]=(float)((Math.Sign(Math.Sin(ph))*0.35+Math.Sin(ph)*0.6)*Math.Exp(-t*17)+0.4*Noise()*Math.Exp(-t*60)); } return d; }
  // heavy minigun shot
  public static float[] Minigun(){ var d=Buf(0.18); double ph=0; for(int i=0;i<d.Length;i++){ double t=(double)i/SR; double f=500*Math.Exp(-t*30)+90; ph+=2*Math.PI*f/SR; d[i]=(float)(Math.Sin(ph)*Math.Exp(-t*22)+0.6*Noise()*Math.Exp(-t*50)); } return d; }
  // class select / ready confirm
  public static float[] Confirm(){ var d=Buf(0.5); double[] fr={523,784}; for(int k=0;k<2;k++){ int s0=(int)(k*0.12*SR); for(int i=0;s0+i<d.Length;i++){ double t=(double)i/SR; d[s0+i]+=(float)(Math.Sin(2*Math.PI*fr[k]*t)*Math.Exp(-t*9)*0.6); } } return d; }
}
"@
foreach($p in @(@('grenade_launch','Thump'),@('grenade_explosion','Boom'),@('gun_reload','Reload'),@('matter_pickup','Pickup'),@('matter_drop','Drop'),@('ui_click','Click'),@('rifle_shot','Rifle'),@('minigun_shot','Minigun'),@('ui_confirm','Confirm'))){
  $d=[Synth]::($p[1]).Invoke()
  [Synth]::Write((Join-Path $Out ($p[0]+'.wav')),$d)
  $p[0]
}
