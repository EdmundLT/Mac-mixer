struct Level {var volume:Double=100; var muted=false; var gain:Float {Float(muted ? 0 : min(100,max(0,volume))/100)}}
