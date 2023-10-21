# encryption and decryption of data using RSA

import os
import sys
from cryptography.hazmat.primitives import serialization, hashes
from cryptography.hazmat.primitives.asymmetric import padding
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

def getKeyPem(private = False, keydir = None):
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
        keyname = "private.pem"
        with open(os.path.join(keydir, keyname), 'rb') as file:
            privatekey = serialization.load_pem_private_key(
                file.read(),
                password = None,
                backend = default_backend())
        return privatekey
    else:
        keyname = "public.pem"
        with open(os.path.join(keydir, keyname), 'rb') as file:
            fdata = file.read()
            publickey = serialization.load_pem_public_key(
                fdata,
                backend = default_backend())
        return publickey


def convertPem(privatekey):
    """ convert rsa key to pem """
    return privatekey.private_bytes(
        encoding = serialization.Encoding.PEM,
        format = serialization.PrivateFormat.OpenSSH,
        encryption_algorithm = serialization.NoEncryption()
    )

def convertPemPub(publickey):
    return publickey.public_bytes(
        encoding = serialization.Encoding.PEM,
        format = serialization.PublicFormat.SubjectPublicKeyInfo
    )


def encrypt(data: str, pubkey) -> bytes:
    ciphertext = pubkey.encrypt(
        data,
        padding.OAEP(
            mgf = padding.MGF1(algorithm=hashes.SHA256()),
            algorithm = hashes.SHA256(),
            label = None
        )
    )
    return ciphertext

def encrypt_pem(data: str, rsakey) -> bytes:    
    key = getKeyPem(private=False)
    # use pubpem to encrypt data
    pubkey = serialization.load_pem_public_key(
        key,
        backend = default_backend()
    )
    ciphertext = pubkey.encrypt(
        data.encode(),
        padding.OAEP(
            mgf = padding.MGF1(algorithm=hashes.SHA256()),
            algorithm = hashes.SHA256(),
            label = None
        )
    )
    return ciphertext


def decrypt_pem(data: bytes) -> str:
    """ decrypts """
    key = getKeyPem(private=True)
    # use private key to decrypt data
    privkey = serialization.load_pem_private_key(
        key,
        password = None,
        backend = default_backend()
    )
    plaintext = privkey.decrypt(
        data.decode(),
        padding.OAEP(
            mgf = padding.MGF1(algorithm=hashes.SHA256()),
            algorithm = hashes.SHA256(),
            label = None
        )
    )
    return plaintext.decode()


if __name__ == "__main__":
    testnonce = "hello"
    ciphertext = encrypt_pem(testnonce, None)
    print(ciphertext)
    plaintext = decrypt_pem(ciphertext)
    print(plaintext)



