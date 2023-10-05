defmodule Blxx.Repo do
  use Ecto.Repo,
    otp_app: :blxx,
    adapter: Ecto.Adapters.Postgres
end
