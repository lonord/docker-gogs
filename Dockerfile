FROM golang:alpine3.11 AS binarybuilder
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && apk --no-cache --no-progress add --virtual \
  build-deps \
  build-base \
  git \
  linux-pam-dev

WORKDIR /gogs.io/gogs
COPY gogs /gogs.io/gogs
RUN make build-no-gen TAGS="cert pam"

FROM alpine:3.11
ENV GOSU_VERSION 1.12
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories \
  && echo http://mirrors.aliyun.com/alpine/edge/community/ >> /etc/apk/repositories \
  && apk --no-cache --no-progress add \
  bash \
  ca-certificates \
  curl \
  wget \
  git \
  linux-pam \
  openssh \
  s6 \
  shadow \
  socat \
  tzdata \
  rsync
RUN set -eux; \
	\
	apk add --no-cache --virtual .gosu-deps \
		dpkg \
		gnupg \
	; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/sbin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/sbin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
# verify the signature
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/sbin/gosu.asc /usr/sbin/gosu; \
	command -v gpgconf && gpgconf --kill all || :; \
	rm -rf "$GNUPGHOME" /usr/sbin/gosu.asc; \
	\
# clean up fetch dependencies
	apk del --no-network .gosu-deps; \
	\
	chmod +x /usr/sbin/gosu

ENV GOGS_CUSTOM /data/gogs

# Configure LibC Name Service
COPY gogs/docker/nsswitch.conf /etc/nsswitch.conf

WORKDIR /app/gogs
COPY gogs/docker ./docker
COPY --from=binarybuilder /gogs.io/gogs/gogs .

RUN ./docker/finalize.sh

# Configure Docker Container
VOLUME ["/data", "/backup"]
EXPOSE 22 3000
ENTRYPOINT ["/app/gogs/docker/start.sh"]
CMD ["/bin/s6-svscan", "/app/gogs/docker/s6/"]