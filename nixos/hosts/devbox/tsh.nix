# tsh must not be newer than the Teleport server it talks to, and nixpkgs only ships 17+
{
  stdenv,
  fetchzip,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "tsh";
  version = "15.5.4";

  src = fetchzip {
    url = "https://cdn.teleport.dev/teleport-v${version}-linux-amd64-bin.tar.gz";
    hash = "sha256-/0wQ0/nfkVYVJmB6t/Ztw0KKFxis5s+IePKbtRn0ofM=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    install -Dm755 tsh $out/bin/tsh
  '';
}
