class Iago < Formula
  desc "AI-powered PR review daemon — monitors GitHub and reviews PRs with Claude Code"
  homepage "https://github.com/alepalma91/iago"
  version "0.1.0"
  license "MIT"

  depends_on "gh"
  depends_on :macos

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/alepalma91/iago/releases/download/v0.1.0/iago-0.1.0-darwin-arm64.tar.gz"
      sha256 "dbbb5fce0e007ca82bd113db94a10caffc3500da33e771ca6b1fd767398b11d4"
    end
  end

  def install
    bin.install "iago"
    bin.install "iago-bar" if File.exist?("iago-bar")
    (pkgshare/"prompts").install "system.md"
    (pkgshare/"prompts").install "instructions.md"
  end

  def post_install
    config_dir = etc/"iago"
    prompts_dir = config_dir/"prompts"
    prompts_dir.mkpath

    unless (prompts_dir/"system.md").exist?
      cp pkgshare/"prompts/system.md", prompts_dir/"system.md"
    end
    unless (prompts_dir/"instructions.md").exist?
      cp pkgshare/"prompts/instructions.md", prompts_dir/"instructions.md"
    end

    unless (config_dir/"config.yaml").exist?
      (config_dir/"config.yaml").write <<~YAML
        # iago configuration
        github:
          poll_interval: 60s
          watched_repos: []
          ignored_repos: []
        launchers:
          max_parallel: 3
          default_tools:
            - claude
        prompts:
          system_prompt: #{prompts_dir}/system.md
          instructions: #{prompts_dir}/instructions.md
        notifications:
          native: true
        dashboard:
          enabled: true
          port: 1460
      YAML
    end

    user_config = Pathname.new(Dir.home)/".config/iago"
    unless user_config.exist?
      user_config.mkpath
      FileUtils.ln_sf config_dir/"config.yaml", user_config/"config.yaml"
      FileUtils.ln_sf config_dir/"prompts", user_config/"prompts"
    end
  end

  def caveats
    <<~EOS
      iago requires Claude Code CLI to review PRs:
        https://docs.anthropic.com/en/docs/claude-code

      For rich notifications with action buttons:
        brew install alerter

      Config: #{etc}/iago/config.yaml (symlinked to ~/.config/iago/)
      Data:   ~/.local/share/iago/

      To start: iago start
      To setup: iago setup
    EOS
  end

  test do
    assert_match "iago", shell_output("#{bin}/iago --help 2>&1", 0)
  end
end
