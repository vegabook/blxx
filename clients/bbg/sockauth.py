# encryption and decryption of data using RSA

import os
import sys
from cryptography.hazmat.primitives import serialization 
#from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend
from colorama import Fore, Style, init as colinit; colinit() 

# read my public or private key id_rsa.pub under Windows
def getKey(private = False, keypath = None):
    if keypath is None:
        if sys.platform == 'win32':
            homedir = os.environ.get('USERPROFILE')  
        else:
            homedir = os.environ.get('HOME')
        if homedir is None:
            raise EnvironmentError("Home directory not found in environment variables.")
        keypath = os.path.join(homedir, '.ssh')
        if private:
            keypath = os.path.join(keypath, "id_rsa")
        else:
            keypath = os.path.join(keypath, "id_rsa.pub")
    if not os.path.exists(keypath):
        print(f"{Fore.RED}{Style.BRIGHT}Have you run ssh_keygen?{Style.RESET_ALL}")
        raise FileNotFoundError(f"{keypath} not found.")
    if private:
        with open(keypath, 'rb') as file:
            privatekey = serialization.load_ssh_private_key(
                file.read(),
                password = None,
                backend = default_backend())
        return privatekey
    else:
        with open(keypath, 'rb') as file:
            fdata = file.read()
            publickey = serialization.load_ssh_public_key(
                fdata,
                backend = default_backend())
        return publickey


if __name__ == "__main__":
    key = getKey(private = False)
    print(key.public_numbers().n)



