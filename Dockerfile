FROM golang:1.21 as supervisor

ARG svVersion="0.7.3"

RUN cd /tmp && \
    curl -L -O https://github.com/ochinchina/supervisord/archive/refs/tags/v${svVersion}.tar.gz && \
    tar -xzf v${svVersion}.tar.gz && \
    cd supervisord-${svVersion} && \
    go get -d github.com/UnnoTed/fileb0x@v1.1.4 && \
    go get -d github.com/prometheus/client_golang@v1.11.1 && \
    go get -d golang.org/x/sys@v0.0.0-20220412211240-33da011f77ad && \
    go get -d golang.org/x/net@v0.7.0 && \
    go generate && \
    GOOS=linux go build -tags release -a -ldflags "-linkmode external -extldflags -static" -o supervisord && \
    mv supervisord /usr/local/bin/supervisord && \
    cd /tmp && \
    rm -rf supervisord-${svVersion}

FROM python:3.7-alpine

ENV ZING_VERSION="0.9.7"
ENV SERGE_VERSION="1.4"
ENV NODE_VERSION="v14.21.3"

RUN chmod -R 2777 /tmp

RUN apk add --no-cache --update \
    mariadb-client \
    mariadb-connector-c \
    bash \
    xz \
    git \
    wget \
    curl \
    unzip \
    libxslt \
    libxml2 \
    perl-app-cpanminus \
    perl-xml-twig \
    perl-xml-libxml \
    perl-xml-libxslt \
    mariadb-client \
    openssh-client && \
    apk add --no-cache --virtual  .build-deps \
    alpine-sdk \
    autoconf \
    automake \
    perl-dev \
    mariadb-dev && \
    cd /tmp && \
    wget https://unofficial-builds.nodejs.org/download/release/$NODE_VERSION/node-$NODE_VERSION-linux-x64-musl.tar.xz && \
    tar -xf node-$NODE_VERSION-linux-x64-musl.tar.xz && \
    ln -s /tmp/node-$NODE_VERSION-linux-x64-musl/bin/node /usr/local/bin/node && \
    ln -s /tmp/node-$NODE_VERSION-linux-x64-musl/bin/npm /usr/local/bin/npm && \
    ln -s /tmp/node-$NODE_VERSION-linux-x64-musl/bin/npx /usr/local/bin/npx && \
    mkdir -p /srv/zing/po/.tmp && \
    pip install --upgrade pip && \
    pip install mysqlclient && \
    cd /srv/zing && \
    wget https://github.com/evernote/zing/archive/v$ZING_VERSION.zip && \
    unzip v$ZING_VERSION.zip && \
    rm v$ZING_VERSION.zip && \
    # patch zing for python 3
    sed -i "s|import syspath_override|from .syspath_override import *|" /srv/zing/zing-$ZING_VERSION/pootle/runner.py && \
    # patch dependencies for security
    sed -i "s|lxml==4.4.2|lxml>=4.4.2|" /srv/zing/zing-$ZING_VERSION/requirements/base.txt && \
    sed -i "s|Django==3.1.12|Django==3.1.14|" /srv/zing/zing-$ZING_VERSION/requirements/base.txt && \
    # update js dependencies
    cd /srv/zing/zing-$ZING_VERSION/pootle/static/js && \
    npm install && \
    npm audit fix && \
    npm install underscore@1.13.6 && \
    npm install mocha@10.2.0 && \
    npm install webpack@~4 && \
    npm install webpack-cli@~3 && \
    npm install decode-uri-component@0.2.1 && \
    npm install semver@5.7.2 && \
    npm audit fix && \
    rm -rf node_modules && \
    # add no critical checker option
    cp /srv/zing/zing-$ZING_VERSION/pootle/apps/pootle_misc/checks.py /srv/zing/zing-$ZING_VERSION/pootle/apps/pootle_misc/no_checks.py && \
    sed -i "s|@critical|@cosmetic|" /srv/zing/zing-$ZING_VERSION/pootle/apps/pootle_misc/no_checks.py && \
    sed -i "s|ENChecker|NonChecker|" /srv/zing/zing-$ZING_VERSION/pootle/apps/pootle_misc/no_checks.py && \
    pip install -e /srv/zing/zing-$ZING_VERSION && \
    zing init && \
    zing build_assets && \
    cp -r /srv/zing/zing-$ZING_VERSION/pootle/assets/translations/en /srv/zing/zing-$ZING_VERSION/pootle/assets/translations/en-us && \
    cd /usr/lib && \
    wget -q https://github.com/evernote/serge/archive/$SERGE_VERSION.zip -O serge-$SERGE_VERSION.zip && \
    unzip serge-$SERGE_VERSION.zip && \
    rm serge-$SERGE_VERSION.zip && \
    ln -s /usr/lib/serge-$SERGE_VERSION /usr/lib/serge && \
    cd /usr/lib/serge && \
    cpanm --installdeps . && \
    cpanm --test-only . && \
    ./Build distclean && \
    ln -s /usr/lib/serge/bin/serge /usr/bin/serge && \
    apk del .build-deps && \
    rm /usr/local/bin/node && \
    rm /usr/local/bin/npm && \
    rm /usr/local/bin/npx && \
    rm -rf /tmp/* && \
    rm -rf /root/.npm && \
    rm -rf /root/.cpanm && \
    rm -rf /root/.cache/pip && \
    rm -rf /var/cache/apk/*

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY --from=supervisor /usr/local/bin/supervisord /usr/local/bin/supervisord

# Configure zing
COPY zing.sh /etc/profile.d/zing.sh
COPY zing.conf /root/.zing/zing.conf

WORKDIR /var/serge/projects/
RUN git config --global --add safe.directory /var/serge/projects

EXPOSE 8000

CMD ["/usr/local/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
