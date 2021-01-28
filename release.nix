# If you would like to test and build changes quickly using `cabal`, run:
#
#     $ nix-shell
#     [nix-shell]$ cabal configure --enable-tests && cabal test
#
# This will open up a Nix shell where all of your Haskell tools will work like
# normal, except that all dependencies (including C libraries) are managed by
# Nix.  The only thing that won't work is running tests inside this shell
# (although you can still build them).  Fixing the test suite requires
# extensive patching of the test scripts (see `postPatch` below)
#
# Note that this will compile the library once without tests using Nix.  This
# is due to the fact that `grpc-haskell`'s test suite cannot test code
# generation without the library being built at least once.
#
# If you want to build and test this repository using `nix`, you can run the
# following command:
#
#     $ nix-build --attr grpc-haskell release.nix
#
# ... but this is not recommended for normal development because this will
# rebuild the repository from scratch every time, which is extremely slow.  Only
# do this if you want to exactly reproduce our continuous integration build.
#
# If you update the `grpc-haskell.cabal` file (such as changing dependencies or
# adding new library/executable/test/benchmark sections), then update the
# `default.nix` expression by running:
#
#     $ cabal2nix . > default.nix
#
# By default, Nix will pick a version for each one of your Haskell dependencies.
# If you would like to select a different version then, run:
#
#     $ cabal2nix cabal://${package-name}-${version} > nix/${package-name}.nix
#
# ... and then add this line below in the Haskell package overrides section:
#
#     ${package-name} =
#       haskellPackagesNew.callPackage ./nix/${package-name}.nix { };
#
# ... replacing `${package-name}` with the name of the package that you would
# like to upgrade and `${version}` with the version you want to upgrade to.
#
# You can also add private Git dependencies in the same way, except supplying
# the `git` URL to clone:
#
#     $ cabal2nix <your private git url>/${package-name}.git > ./nix/${package-name}.nix
#
# ...but also be sure to supply `fetchgit = pkgs.fetchgitPrivate` in the
# `haskellPackagesNew.callPackage` invocation for your private package.
#
# Note that `cabal2nix` also takes an optional `--revision` flag if you want to
# pick a revision other than the latest to depend on.
#
# Finally, if you want to test a local source checkout of a dependency, then
# run:
#
#     $ cabal2nix path/to/dependency/repo > nix/${package-name}.nix
let
  nixpkgs = import ./nixpkgs.nix;

  config = {
    allowUnfree = true;
    # For parameterized-0.5.0.0, which we patch for compatbility with
    # proto3-wire-1.2.0 (which also uses the same patch)
    allowBroken = true;
  };

  overlay = pkgsNew: pkgsOld: {

    cython = pkgsNew.pythonPackages.buildPythonPackage rec {
      name = "Cython-${version}";
      version = "0.24.1";

      src = pkgsNew.fetchurl {
        url = "mirror://pypi/C/Cython/${name}.tar.gz";
        sha256 = "84808fda00508757928e1feadcf41c9f78e9a9b7167b6649ab0933b76f75e7b9";
      };

      # This workaround was taken from https://github.com/NixOS/nixpkgs/issues/18729
      # This was fixed in `nixpkgs-unstable` so we can get rid of this workaround
      # when that fix is stabilized
      NIX_CFLAGS_COMPILE =
        pkgsNew.stdenv.lib.optionalString (pkgsNew.stdenv.cc.isClang or false)
          "-I${pkgsNew.libcxx}/include/c++/v1";

      buildInputs =
            pkgsNew.stdenv.lib.optional (pkgsNew.stdenv.cc.isClang or false) pkgsNew.libcxx
        ++  [ pkgsNew.pkgconfig pkgsNew.gdb ];

      doCheck = false;

      doHaddock = false;

      doHoogle = false;

      meta = {
        description = "An optimising static compiler for both the Python programming language and the extended Cython programming language";
        platforms = pkgsNew.stdenv.lib.platforms.all;
        homepage = http://cython.org;
        license = pkgsNew.stdenv.lib.licenses.asl20;
        maintainers = with pkgsNew.stdenv.lib.maintainers; [ fridh ];
      };
    };

    grpc = pkgsNew.callPackage ./nix/grpc.nix { };

    grpcio = pkgsNew.pythonPackages.buildPythonPackage rec {
      name = "grpc-${version}";

      version = "1.0";

      src = pkgsNew.fetchgit {
        url    = "https://github.com/grpc/grpc.git";
        rev    = "e2cfe9df79c4eda4e376222df064c4c65e616352";
        sha256 = "19ldbjlnbc287hkaylsigm8w9fai2bjdbfxk6315kl75cq54iprr";
      };

      preConfigure = ''
        export GRPC_PYTHON_BUILD_WITH_CYTHON=1
      '';

      # This workaround was taken from https://github.com/NixOS/nixpkgs/issues/18729
      # This was fixed in `nixpkgs-unstable` so we can get rid of this workaround
      # when that fix is stabilized
      NIX_CFLAGS_COMPILE =
        pkgsNew.stdenv.lib.optionalString (pkgsNew.stdenv.cc.isClang or false)
          "-I${pkgsNew.libcxx}/include/c++/v1";

      buildInputs =
        pkgsNew.stdenv.lib.optional (pkgsNew.stdenv.cc.isClang or false) pkgsNew.libcxx;

      propagatedBuildInputs = [
        pkgsNew.cython
        pkgsNew.pythonPackages.futures
        pkgsNew.protobuf3_2NoCheck
        pkgsNew.pythonPackages.enum34
      ];
    };

    grpcio-tools = pkgsNew.pythonPackages.buildPythonPackage rec {
      name = "grpc-${version}";

      version = "1.0";

      src = pkgsNew.fetchgit {
        url    = "https://github.com/grpc/grpc.git";
        rev    = "e2cfe9df79c4eda4e376222df064c4c65e616352";
        sha256 = "19ldbjlnbc287hkaylsigm8w9fai2bjdbfxk6315kl75cq54iprr";
      };

      preConfigure = ''
        export GRPC_PYTHON_BUILD_WITH_CYTHON=1
        cd tools/distrib/python/grpcio_tools
        python ../make_grpcio_tools.py
      '';

      # This workaround was taken from https://github.com/NixOS/nixpkgs/issues/18729
      # This was fixed in `nixpkgs-unstable` so we can get rid of this workaround
      # when that fix is stabilized
      NIX_CFLAGS_COMPILE =
        pkgsNew.stdenv.lib.optionalString (pkgsNew.stdenv.cc.isClang or false)
          "-I${pkgsNew.libcxx}/include/c++/v1";

      buildInputs =
        pkgsNew.stdenv.lib.optional (pkgsNew.stdenv.cc.isClang or false) pkgsNew.libcxx;

      propagatedBuildInputs = [
        pkgsNew.cython
        pkgsNew.pythonPackages.futures
        pkgsNew.protobuf3_2NoCheck
        pkgsNew.pythonPackages.enum34
        pkgsNew.grpcio
      ];
    };

    haskellPackages = pkgsOld.haskellPackages.override {
      overrides = haskellPackagesNew: haskellPackagesOld: rec {

        proto3-wire =
          haskellPackagesNew.callPackage ./nix/proto3-wire.nix { };

        proto3-suite =
          pkgsNew.haskell.lib.dontCheck
            (haskellPackagesNew.callPackage ./nix/proto3-suite.nix {});

        grpc-haskell-core =
          pkgsNew.haskell.lib.buildFromSdist (pkgsNew.usesGRPC
            (pkgsNew.haskell.lib.overrideCabal
              (haskellPackagesNew.callPackage ./core { })
              (_: { buildDepends = [ haskellPackagesNew.c2hs ]; })));

        grpc-haskell-no-tests =
          pkgsNew.haskell.lib.buildFromSdist (pkgsNew.usesGRPC
            (pkgsNew.haskell.lib.dontCheck
              (haskellPackagesNew.callPackage ./default.nix { })
            ));

        grpc-haskell =
          pkgsNew.usesGRPC
            (pkgsNew.haskell.lib.overrideCabal
              (pkgsNew.haskell.lib.buildFromSdist ((haskellPackagesNew.callPackage ./default.nix { })))
              (oldDerivation:
                let
                  ghc =
                    haskellPackagesNew.ghcWithPackages (pkgs: [
                      pkgs.grpc-haskell-no-tests
                      # Include some additional packages in this custom ghc for
                      # running tests in the nix-shell environment.
                      pkgs.tasty-quickcheck
                      pkgs.turtle
                    ]);

                  python = pkgsNew.python.withPackages (pkgs: [
                    # pkgs.protobuf3_0
                    pkgsNew.grpcio-tools
                  ]);

                in rec {
                  configureFlags = (oldDerivation.configureFlags or []) ++ [
                    "--flags=with-examples"
                  ];

                  buildDepends = [
                    pkgsNew.makeWrapper
                    # Give our nix-shell its own cabal so we don't pick up one
                    # from the user's environment by accident.
                    haskellPackagesNew.cabal-install

                    # And likewise for c2hs
                    haskellPackagesNew.c2hs
                  ];

                  patches = [ tests/tests.patch ];

                  postPatch = ''
                    patchShebangs tests
                    substituteInPlace tests/simple-client.sh \
                      --replace @makeWrapper@ ${pkgsNew.makeWrapper} \
                      --replace @grpc@ ${pkgsNew.grpc}
                    substituteInPlace tests/simple-server.sh \
                      --replace @makeWrapper@ ${pkgsNew.makeWrapper} \
                      --replace @grpc@ ${pkgsNew.grpc}
                    wrapProgram tests/protoc.sh \
                      --prefix PATH : ${python}/bin
                    wrapProgram tests/test-client.sh \
                      --prefix PATH : ${python}/bin
                    wrapProgram tests/test-server.sh \
                      --prefix PATH : ${python}/bin
                    wrapProgram tests/simple-client.sh \
                      --prefix PATH : ${ghc}/bin
                    wrapProgram tests/simple-server.sh \
                      --prefix PATH : ${ghc}/bin
                  '';

                  shellHook = (oldDerivation.shellHook or "") + ''
                    # This lets us use our custom ghc and python environments in the shell.
                    export PATH=${ghc}/bin:${python}/bin''${PATH:+:}$PATH
                  '';
                })
            );

        parameterized = pkgsNew.haskell.lib.appendPatch haskellPackagesOld.parameterized ./nix/parameterized.patch;

      };
    };

    protobuf3_2NoCheck =
      pkgsNew.stdenv.lib.overrideDerivation
        pkgsNew.pythonPackages.protobuf
        (oldAttrs : {doCheck = false; doInstallCheck = false;});

    test-grpc-haskell =
      pkgsNew.mkShell {
        nativeBuildInputs = [
          (pkgsNew.haskellPackages.ghcWithPackages (pkgs: [
                pkgs.grpc-haskell
              ]
            )
          )
        ];
      };

    usesGRPC = haskellPackage:
      pkgsNew.haskell.lib.overrideCabal haskellPackage (oldAttributes: {
          preBuild = (oldAttributes.preBuild or "") +
            pkgsNew.lib.optionalString pkgsNew.stdenv.isDarwin ''
              export DYLD_LIBRARY_PATH=${pkgsNew.grpc}/lib''${DYLD_LIBRARY_PATH:+:}$DYLD_LIBRARY_PATH
            '' +
            pkgsNew.lib.optionalString pkgsNew.stdenv.isLinux ''
              export LD_LIBRARY_PATH=${pkgsNew.grpc}/lib''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH
            '';

          shellHook = (oldAttributes.shellHook or "") +
            pkgsNew.lib.optionalString pkgsNew.stdenv.isDarwin ''
              export DYLD_LIBRARY_PATH=${pkgsNew.grpc}/lib''${DYLD_LIBRARY_PATH:+:}$DYLD_LIBRARY_PATH
            '' +
            pkgsNew.lib.optionalString pkgsNew.stdenv.isLinux ''
              export LD_LIBRARY_PATH=${pkgsNew.grpc}/lib''${LD_LIBRARY_PATH:+:}$LD_LIBRARY_PATH
            '';
        }
      );
  };

  overlays = [ overlay ];

in

let
   linuxPkgs = import nixpkgs { inherit config overlays; system = "x86_64-linux" ; };
  darwinPkgs = import nixpkgs { inherit config overlays; system = "x86_64-darwin"; };
        pkgs = import nixpkgs { inherit config overlays; };

in
  {
    grpc-haskell-core-linux    =  linuxPkgs.haskellPackages.grpc-haskell-core;
    grpc-haskell-core-darwin   = darwinPkgs.haskellPackages.grpc-haskell-core;
    grpc-haskell-core          =       pkgs.haskellPackages.grpc-haskell-core;

    grpc-haskell-linux         =  linuxPkgs.haskellPackages.grpc-haskell;
    grpc-haskell-darwin        = darwinPkgs.haskellPackages.grpc-haskell;
    grpc-haskell               =       pkgs.haskellPackages.grpc-haskell;
    grpc-haskell-no-tests      =       pkgs.haskellPackages.grpc-haskell-no-tests;

    grpc-linux                 =  linuxPkgs.grpc;
    grpc-darwin                = darwinPkgs.grpc;

    grpc                       =       pkgs.grpc;

    inherit (pkgs) test-grpc-haskell;
  }
