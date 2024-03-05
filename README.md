## pass-sshkey : Enhancing SSH Keys Management Workflow. 

pass-sshkey is a [Password Store](https://www.passwordstore.org/) extension.

The extension augments the functionality of pass, the standard Unix password manager, in order to provide an enhanced SSH keys management workflow.

Designed to streamline SSH key-pair management, this extension leverage pass's robust encryption and organizational capabilities.
Keys are managed both in Password Store and `$HOME/.ssh/`, while the passphrase is securely encrypted only in Password Store.
It seamlessly integrates with pass to generate random passphrases by default. 
Moreover, users retain the flexibility to define custom passphrases or opt for passphrase-less key generation. 

For heightened security and convenience, users can utilize pass in conjunction with Tomb (the Crypto Undertaker) to create locked folders with their password store. 
This enables safe transportation and concealment of SSH keys.

This program is free software: you can redistribute it and/or modify it under the terms of the GPLv2. See [LICENSE](https://github.com/zidenis/pass-extension-sshkey/blob/main/LICENSE).
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY.

### Usage

```
pass sshkey generate pass-name [-t keytype] [-b bits] [-p[passphrase], --pass[=passphrase]] [-c ent] [-v]

    Creates an SSH key-pair and securely stores it in both 'Password Store' and '$HOME/.ssh/'
    By default, the private key is created with a randomly generated passphrase provided by pass.
    The random passphrase properties are defined by pass environment variables like
    $PASSWORD_STORE_GENERATED_LENGTH and $PASSWORD_STORE_CHARACTER_SET.
    However, you can specify a custom passphrase using '-p,--pass' option. If used without
    an argument, the script prompts you to enter the passphrase interactively.
    A passphrase file is then saved in 'pass-name/passphrase' location.
    To create a key without a passphrase, use '-n, --nopass' option.
    The script outputs the generated SSH public key.

    Options:
        -b, --keybits           The number of bits in the key.
        -c, --clip              Put the passphrase on the clipboard and clear th board
                                after $PASSWORD_STORE_CLIP_TIME seconds.
        -C, --comment           Provide a comment to help identify the key.
        -n, --nopass            Creates a private key without a passphrase.
        -p, --pass              Defines a custom passphrase for the private key.
                                If used without an argument, the passphrase is prompted.
        -t, --keytype           Specifies the type of the key.
                                Valid types: dsa|ecdsa|ecdsa-sk|ed25519|ed25519-sk|rsa
        -v, --verbose           Enables verbose output.
```

```
pass sshkey rm pass-name [-y] [-v]

  Remove existing ssh key-pairs and passphrases from 'Password Store' and also from '$HOME/.ssh/' ctory.
  Caution: likewise 'pass rm --recursive pass-name', 'sshkey rm' removes the entire pass-name ctory tree.

  Options:
      -y                        Remove the key-pairs without confirmation.
      -v, --verbose
```

```
pass sshkey restore [pass-name]

  Restore ssh keys found in 'Password Store' to '$HOME/.ssh/' directory.
  Only private and public keys are restored. Passphrases files remains in 'Password Store' only.
  Usefull to, for example, after moving your Password Store to a new machine.
  If provided, 'pass-name' will specify which keys should be restored.
  Otherwise, all keys found in 'Password Store' will be restored.
```
