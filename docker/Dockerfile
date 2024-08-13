ARG swift_version=5.8
ARG ubuntu_version=jammy
ARG base_image=swift:$swift_version-$ubuntu_version
FROM $base_image
# needed to do again after FROM due to docker limitation
ARG swift_version
ARG ubuntu_version

# set as UTF-8
RUN apt-get update && apt-get install -y locales locales-all
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

# dependencies
RUN apt-get update && apt-get install -y wget
RUN apt-get update && apt-get install -y lsof dnsutils netcat-openbsd net-tools libz-dev curl jq # used by integration tests

# install jemalloc for running allocation benchmarks
RUN apt-get update & apt-get install -y libjemalloc-dev

# ruby and jazzy for docs generation
RUN apt-get update && apt-get install -y ruby ruby-dev libsqlite3-dev build-essential
# jazzy no longer works on xenial as ruby is too old.
RUN if [ "${ubuntu_version}" = "focal" ] ; then echo "gem: --no-document" > ~/.gemrc; fi
RUN if [ "${ubuntu_version}" = "focal" ] ; then gem install jazzy; fi

# tools
RUN mkdir -p $HOME/.tools
RUN echo 'export PATH="$HOME/.tools:$PATH"' >> $HOME/.profile

# swift-format (until part of the toolchain)
RUN mkdir -p $HOME/.deps
RUN git clone --branch release/$swift_version --depth 1 https://github.com/apple/swift-format $HOME/.deps/swift-format
RUN cd $HOME/.deps/swift-format && swift build -c release
RUN ln -s $HOME/.deps/swift-format/.build/release/swift-format $HOME/.tools
