FROM python:3.7-slim-buster
ENV ZING_VERSION="v0.9.7"
ENV SERGE_VERSION="1.4"

RUN chmod -R 2777 /tmp

# Install apt packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
    xsltproc \
    build-essential \
    libexpat-dev \
    libxml2-dev \
    libssl-dev \
    libxslt-dev \
    zlib1g-dev \
    cpanminus \
    git \
    cron \
    wget \
    curl \
    supervisor \
    unzip \
    mariadb-client \
    libmariadb-dev-compat \
    libmariadb-dev \
    openssh-client && \
    curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs && \
    mkdir -p /srv/zing/po/.tmp && \
    pip install --upgrade pip && \
    pip install mysqlclient && \
    pip install https://github.com/evernote/zing/archive/$ZING_VERSION.zip && \
    sed -i "s|import syspath_override|from .syspath_override import *|" /usr/local/lib/python3.7/site-packages/pootle/runner.py && \
    zing --version && \
    npm i npm@latest -g && \
    zing init && \
    zing build_assets && \
    cp -r /usr/local/lib/python3.7/site-packages/pootle/assets/translations/en /usr/local/lib/python3.7/site-packages/pootle/assets/translations/en-us && \
    cd /usr/lib && \
    wget -q https://github.com/evernote/serge/archive/$SERGE_VERSION.zip -O serge-$SERGE_VERSION.zip && \
    unzip serge-$SERGE_VERSION.zip && \
    unlink serge-$SERGE_VERSION.zip && \
    cpan App::cpanminus && \
    cp -r /usr/include/libxml2/libxml /usr/include/ && \
    ln -s /usr/lib/serge-$SERGE_VERSION /usr/lib/serge && \
    cd /usr/lib/serge && \
    cpanm --installdeps . && \
    cpanm --test-only . && \
    ./Build distclean && \
    ln -s /usr/lib/serge/bin/serge /usr/bin/serge && \
    apt-get purge -y \
    build-essential \
    libexpat-dev \
    libxml2-dev \
    libssl-dev \
    libxslt-dev \
    zlib1g-dev \
    libmariadb-dev-compat \
    libmariadb-dev \
    nodejs && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    cp /usr/local/lib/python3.7/site-packages/pootle/apps/pootle_misc/checks.py /usr/local/lib/python3.7/site-packages/pootle/apps/pootle_misc/no_checks.py && \
    sed -i "s|@critical|@cosmetic|" /usr/local/lib/python3.7/site-packages/pootle/apps/pootle_misc/no_checks.py && \
    sed -i "s|ENChecker|NonChecker|" /usr/local/lib/python3.7/site-packages/pootle/apps/pootle_misc/no_checks.py

# Configure zing
COPY zing.sh /etc/profile.d/zing.sh
COPY zing.conf /root/.zing/zing.conf

WORKDIR /var/serge/projects/

EXPOSE 8000
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord"]
