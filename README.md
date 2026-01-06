# iss-display
---

### Build container
```
$ podman build -t iss-display .
```

## Run Container
```
$ ./run.sh
```

## Connect
### Linux / BSD
Use a vnc client to connect
```
$ wlvncc <vnc-server>
# or
$ vinagre [vnc-server:5910]
```
### macOS
```
$ /Applications/VNC\ Viewer.app/Contents/MacOS/vncviewer localhost:5910
```
