defmodule FSS.S3Test do
  use ExUnit.Case, async: true

  alias FSS.S3
  alias FSS.S3.Config
  alias FSS.S3.Entry

  describe "parse/2" do
    setup do
      default_config = %Config{
        secret_access_key: "my-secret",
        access_key_id: "my-access",
        region: "us-west-2"
      }

      {:ok, config: default_config}
    end

    test "parses a s3:// style uri", %{config: config} do
      assert {:ok, %Entry{key: "my-file.png", config: %Config{} = config}} =
               S3.parse("s3://my-bucket/my-file.png", config: config)

      assert is_nil(config.endpoint)
      assert config.bucket == "my-bucket"
      assert config.secret_access_key == "my-secret"
      assert config.access_key_id == "my-access"
      assert config.region == "us-west-2"
    end

    test "accepts a config as a keyword list" do
      assert {:ok, %Entry{config: %Config{} = config}} =
               S3.parse("s3://my-bucket/my-file.png",
                 config: [
                   endpoint: "localhost",
                   secret_access_key: "my-secret-1",
                   access_key_id: "my-access-key-1",
                   region: "eu-east-1"
                 ]
               )

      assert config.endpoint == "localhost"
      assert config.bucket == "my-bucket"
      assert config.secret_access_key == "my-secret-1"
      assert config.access_key_id == "my-access-key-1"
      assert config.region == "eu-east-1"
    end

    test "accepts a config as a map" do
      assert {:ok, %Entry{config: %Config{} = config}} =
               S3.parse("s3://my-bucket/my-file.png",
                 config: %{
                   endpoint: "localhost",
                   secret_access_key: "my-secret-1",
                   access_key_id: "my-access-key-1",
                   # We always ignore bucket from config.
                   bucket: "random-name",
                   region: "eu-east-1"
                 }
               )

      assert config.endpoint == "localhost"
      assert config.bucket == "my-bucket"
      assert config.secret_access_key == "my-secret-1"
      assert config.access_key_id == "my-access-key-1"
      assert config.region == "eu-east-1"
    end

    test "does not parse an invalid s3 uri using the s3:// schema" do
      assert {:error,
              ArgumentError.exception(
                "expected s3://<bucket>/<key> URL, got: s3://my-bucket-my-file.png"
              )} ==
               S3.parse("s3://my-bucket-my-file.png")
    end

    test "does not parse a valid s3 uri using the http(s):// schema" do
      assert {:error,
              ArgumentError.exception(
                "expected s3://<bucket>/<key> URL, got: https://my-bucket.not-s3.somethig.com/my-file.png"
              )} ==
               S3.parse("https://my-bucket.not-s3.somethig.com/my-file.png")
    end

    test "raise error when missing access key id" do
      assert_raise ArgumentError,
                   "missing :access_key_id for FSS.S3 (set the key or the AWS_ACCESS_KEY_ID env var)",
                   fn ->
                     S3.parse("s3://my-bucket/my-file.png")
                   end
    end

    test "raise error when missing secret key id" do
      assert_raise ArgumentError,
                   "missing :secret_access_key for FSS.S3 (set the key or the AWS_SECRET_ACCESS_KEY env var)",
                   fn ->
                     S3.parse("s3://my-bucket/my-file.png", config: [access_key_id: "my-key"])
                   end
    end

    test "raise error when missing region" do
      assert_raise ArgumentError,
                   "missing :region for FSS.S3 (set the key or the AWS_REGION env var)",
                   fn ->
                     S3.parse("s3://my-bucket/my-file.png",
                       config: [access_key_id: "my-key", secret_access_key: "my-secret"]
                     )
                   end
    end

    test "raise error when config is not valid" do
      assert_raise ArgumentError,
                   "expect configuration to be a %FSS.S3.Config{} struct, a keyword list or a map. Instead got 42",
                   fn ->
                     S3.parse("s3://my-bucket/my-file.png", config: 42)
                   end
    end
  end

  describe "parse_config_from_bucket_url/2" do
    setup do
      default_config = [
        secret_access_key: "my-secret",
        access_key_id: "my-access"
      ]

      [default_config: default_config]
    end

    test "parses a path-style AWS S3 url", %{default_config: default_config} do
      assert {:ok, config} =
               S3.parse_config_from_bucket_url("https://s3.us-west-2.amazonaws.com/my-bucket",
                 config: default_config
               )

      assert %Config{} = config
      assert config.region == "us-west-2"
      assert config.bucket == "my-bucket"
      assert is_nil(config.endpoint)
    end

    test "parses a host-style AWS S3 url", %{default_config: default_config} do
      assert {:ok, config} =
               S3.parse_config_from_bucket_url("https://my-bucket-1.s3.us-west-2.amazonaws.com/",
                 config: default_config
               )

      assert %Config{} = config
      assert config.region == "us-west-2"
      assert config.bucket == "my-bucket-1"
      assert is_nil(config.endpoint)
    end

    test "parses a path-style S3 compatible url", %{default_config: default_config} do
      assert {:ok, config} =
               S3.parse_config_from_bucket_url("https://storage.googleapis.com/my-bucket-on-gcp",
                 config: default_config
               )

      assert %Config{} = config
      assert is_nil(config.region)
      assert config.bucket == "my-bucket-on-gcp"
      assert config.endpoint == "https://storage.googleapis.com"
    end

    test "parses a path-style S3 compatible url with a port", %{default_config: default_config} do
      assert {:ok, config} =
               S3.parse_config_from_bucket_url("http://localhost:4852/my-bucket-on-lh",
                 config: default_config
               )

      assert %Config{} = config
      assert is_nil(config.region)
      assert config.bucket == "my-bucket-on-lh"
      assert config.endpoint == "http://localhost:4852"
    end

    test "cannot extract bucket from host-style S3 url", %{default_config: default_config} do
      assert {:error, error} =
               S3.parse_config_from_bucket_url("https://my-bucket-on-gcp.storage.googleapis.com",
                 config: default_config
               )

      message =
        "cannot extract bucket name from URL. Expected URL in the format " <>
          "https://s3.[region].amazonaws.com/[bucket], got: " <>
          "https://my-bucket-on-gcp.storage.googleapis.com"

      assert error == ArgumentError.exception(message)
    end

    test "cannot parse url without host", %{default_config: default_config} do
      assert {:error, error} =
               S3.parse_config_from_bucket_url("/my-path",
                 config: default_config
               )

      message =
        "expected URL in the format https://s3.[region].amazonaws.com/[bucket], got: /my-path"

      assert error == ArgumentError.exception(message)
    end
  end
end
