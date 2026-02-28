# frozen_string_literal: true

require "test_helper"

class TestConfig < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("mddir-config-test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_defaults_when_no_config_file
    config = Mddir::Config.new(path: File.join(@tmpdir, "nonexistent.yml"))

    assert_equal File.expand_path("~/.mddir"), config.base_dir
    assert_equal 7768, config.port
    assert_includes config.user_agent, "Mozilla"
  end

  def test_custom_config_overrides_defaults
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, YAML.dump("port" => 9999, "base_dir" => "/tmp/custom-mddir"))

    config = Mddir::Config.new(path: config_path)

    assert_equal 9999, config.port
    assert_equal "/tmp/custom-mddir", config.base_dir
  end

  def test_partial_config_keeps_other_defaults
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, YAML.dump("port" => 3000))

    config = Mddir::Config.new(path: config_path)

    assert_equal 3000, config.port
    assert_equal File.expand_path("~/.mddir"), config.base_dir
    assert_includes config.user_agent, "Mozilla"
  end

  def test_corrupted_config_falls_back_to_defaults
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, "{{{{ not valid yaml !!!!")

    config = Mddir::Config.new(path: config_path)

    assert_equal 7768, config.port
    assert_equal File.expand_path("~/.mddir"), config.base_dir
  end

  def test_base_dir_expands_tilde
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, YAML.dump("base_dir" => "~/my-notes"))

    config = Mddir::Config.new(path: config_path)

    assert_equal File.expand_path("~/my-notes"), config.base_dir
    refute_includes config.base_dir, "~"
  end

  def test_create_default_config_writes_file
    config_path = File.join(@tmpdir, "config.yml")
    config = Mddir::Config.new(path: config_path)

    config.create_default_config!

    assert_path_exists config_path
    written = YAML.safe_load_file(config_path)

    assert_equal 7768, written["port"]
  end

  def test_create_default_config_does_not_overwrite_existing
    config_path = File.join(@tmpdir, "config.yml")
    File.write(config_path, YAML.dump("port" => 9999))

    config = Mddir::Config.new(path: config_path)
    config.create_default_config!

    written = YAML.safe_load_file(config_path)

    assert_equal 9999, written["port"]
  end
end
