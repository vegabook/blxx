defmodule Blxx.Crypt.KeyAuth do
  @moduledoc """
  Authenticate an incoming request with a public and private keys
  """

  @doc """
  Reads a public or private key from the specified or default directory.
  """
  def get_key(private \\ false, key_dir \\ nil) do
    key_dir =
      if key_dir do
        key_dir
      else
        case :os.type() do
          {:win32, _} -> System.get_env("USERPROFILE")
          _ -> System.get_env("HOME")
        end
      end

    if key_dir == nil do
      raise "Home directory not found in environment variables."
    end

    ssh_dir = Path.join([key_dir, ".ssh"])

    unless File.exists?(ssh_dir) do
      raise "#{ssh_dir} not found."
    end

    key_name = if private, do: "id_rsa", else: "id_rsa.pub"
    key_path = Path.join([ssh_dir, key_name])

    case File.read(key_path) do
      {:ok, key_data} ->
        if private do
          {:ok, private_key} = :public_key.pem_decode(:RSAPrivateKey, key_data)
          {:ok, private_key}
        else
          {:ok, public_key} = :public_key.pem_decode(:RSAPublicKey, key_data)
          {:ok, {key_data, public_key}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
