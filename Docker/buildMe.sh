#docker build . -f Dockerfile --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t elinux:latest --progress=plain --no-cache

#docker build . -f Dockerfile --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t elinux:latest --progress=plain


docker build . -f Dockerfile --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t elinux:latest
