FROM ocaml/opam2:debian-10-ocaml-4.08 AS build
RUN sudo apt-get update && sudo apt-get install graphviz m4 pkg-config libsqlite3-dev -y --no-install-recommends
RUN cd ~/opam-repository && git pull origin master && git reset --hard f372039db86a970ef3e662adbfe0d4f5cd980701 && opam update
COPY --chown=opam ocurrent/current.opam ocurrent/current_web.opam ocurrent/current_docker.opam ocurrent/current_git.opam /src/ocurrent/
RUN opam pin -y add /src/ocurrent
COPY --chown=opam base-images.opam /src/
WORKDIR /src
RUN opam install -y --deps-only .
ADD --chown=opam . .
RUN opam config exec -- dune build ./src/base_images.exe

FROM debian:10
RUN apt-get update && apt-get install openssh-client curl dumb-init git graphviz libsqlite3-dev ca-certificates -y --no-install-recommends
RUN apt-get install gnupg2 -y --no-install-recommends
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN echo 'deb [arch=amd64] https://download.docker.com/linux/debian buster stable' >> /etc/apt/sources.list
RUN apt-get update && apt-get install docker-ce -y --no-install-recommends
RUN mkdir /root/.ssh && chmod 0700 /root/.ssh && ln -s /run/secrets/ocurrent-ssh-key /root/.ssh/id_rsa
COPY known_hosts /root/.ssh/known_hosts
COPY dot_docker /root/.docker
COPY --from=build /src/_build/default/src/base_images.exe /usr/local/bin/base-images
WORKDIR /var/lib/ocurrent
ENTRYPOINT ["dumb-init", "/usr/local/bin/base-images"]
