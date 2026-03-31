class Iago < Formula
  desc "AI-powered PR review daemon — monitors GitHub and reviews PRs with Claude Code"
  homepage "https://github.com/alepalma91/iago"
  url "https://github.com/alepalma91/iago.git", branch: "main"
  version "0.1.0"
  license "MIT"

  depends_on "gh"
  depends_on "oven-sh/bun/bun"

  def install
    # Install dependencies
    system "bun", "install"

    # Compile standalone binary
    system "bun", "build", "--compile", "--minify", "src/index.ts", "--outfile", "iago"
    bin.install "iago"

    # Build menubar app (best-effort, not fatal if it fails)
    if which("swiftc")
      menubar_ok = quiet_system("make", "menubar-build")
      if menubar_ok && File.exist?("extras/menubar/iago-bar")
        bin.install "extras/menubar/iago-bar"
      else
        opoo "Menu bar app build failed (optional). Update Xcode Command Line Tools to enable it."
      end
    end

    # Install default prompts
    (pkgshare/"prompts").install "install-prompts/system.md"
    (pkgshare/"prompts").install "install-prompts/instructions.md"
  end

  def post_install
    config_dir = etc/"iago"
    prompts_dir = config_dir/"prompts"
    prompts_dir.mkpath

    # Copy default prompts if not present
    unless (prompts_dir/"system.md").exist?
      cp pkgshare/"prompts/system.md", prompts_dir/"system.md"
    end
    unless (prompts_dir/"instructions.md").exist?
      cp pkgshare/"prompts/instructions.md", prompts_dir/"instructions.md"
    end

    # Create default config if not present
    unless (config_dir/"config.yaml").exist?
      (config_dir/"config.yaml").write <<~YAML
        # iago configuration
        # See: https://github.com/alepalma91/iago

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

    # Symlink config to user's expected location
    user_config = Pathname.new(Dir.home)/".config/iago"
    unless user_config.exist?
      user_config.mkpath
      FileUtils.ln_sf config_dir/"config.yaml", user_config/"config.yaml"
      FileUtils.ln_sf config_dir/"prompts", user_config/"prompts"
    end
  end

  def caveats
    s = <<~EOS
      iago requires Claude Code CLI to review PRs:
        https://docs.anthropic.com/en/docs/claude-code

      For rich notifications with action buttons:
        brew install alerter

      Config: #{etc}/iago/config.yaml (symlinked to ~/.config/iago/)
      Data:   ~/.local/share/iago/

      To start the daemon:
        iago start

      To run setup wizard:
        iago setup
    EOS
    unless (bin/"iago-bar").exist?
      s += <<~EOS

        Menu bar app was not built. To enable it, update Xcode Command Line Tools:
          sudo rm -rf /Library/Developer/CommandLineTools
          sudo xcode-select --install
        Then reinstall: brew reinstall iago
      EOS
    end
    s
  end

  test do
    assert_match "iago", shell_output("#{bin}/iago --help 2>&1", 0)
  end
end
