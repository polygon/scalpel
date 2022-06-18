{
  writeShellScript,
  gnused,
  matchers,
  source,
  destination,
  user ? null,
  group ? null,
  mode ? null
}:
let
  matcher_names = builtins.attrNames matchers;
  loaders = builtins.concatStringsSep "\n" (
    builtins.map (name:
      "MATCHERS[${name}]=$(cat ${matchers."${name}"})"
    ) matcher_names
  );
  sed_rules = builtins.concatStringsSep ";" (
    builtins.map (name:
      "s/!!${name}!!/\${MATCHERS[${name}]}/g"
    ) matcher_names
  );
  chown = if user == null then "" else "chown ${user} ${destination}";
  chgrp = if group == null then "" else "chgrp ${group} ${destination}";
  chmod = if mode == null then "" else "chmod ${mode} ${destination}";
in
  writeShellScript "scalpel" (builtins.concatStringsSep "\n" [
    "declare -A MATCHERS"
    "${loaders}" 
    ''${gnused}/bin/sed -e "${sed_rules}" ${source} > ${destination}''
    chown
    chgrp
    chmod
  ])