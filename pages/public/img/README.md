```
identify -format "%wx%h"  logo.png
```

```
convert source.png -resize 320x320 screenshot_320x320.png
convert source.png -resize 192x192 icon_192x192.png
convert source.png -resize 512x512 icon_512x512.png
convert source.png -resize 104x104 logo.png
convert source.png -resize 64x64 ../favicon.ico
convert source.png -resize 384x384 ../favicon.png
````
