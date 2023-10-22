# encryption and decryption of data using RSA

import os
import sys
from cryptography.hazmat.primitives import serialization 
#from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.hazmat.backends import default_backend


# read my public or private key id_rsa.pub under Windows
def getKey(private = False, keydir = None):
    if keydir is None:
        # Windows
        if sys.platform == 'win32':
            homedir = os.environ.get('USERPROFILE')  
        else:
            homedir = os.environ.get('HOME')
        if homedir is None:
            raise EnvironmentError("Home directory not found in environment variables.")
        keydir = os.path.join(homedir, '.ssh')
    if not os.path.exists(keydir):
        raise FileNotFoundError(f"{keydir} not found.")
    if private:
        keyname = "id_rsa"
        with open(os.path.join(keydir, keyname), 'rb') as file:
            privatekey = serialization.load_ssh_private_key(
                file.read(),
                password = None,
                backend = default_backend())
        return privatekey
    else:
        keyname = "id_rsa.pub"
        with open(os.path.join(keydir, keyname), 'rb') as file:
            fdata = file.read()
            publickey = serialization.load_ssh_public_key(
                fdata,
                backend = default_backend())
        return publickey



if __name__ == "__main__":
    key = getKey(private = False)
    print(key.public_numbers().n)



