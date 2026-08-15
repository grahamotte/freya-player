require_relative "../test_helper"

class GitRepoPatchTest < Minitest::Test
  def test_skips_blank_repositories
    codeberg = ENV["CODEBERG_REPO"]
    github = ENV["GITHUB_REPO"]
    ENV["CODEBERG_REPO"] = ""
    ENV["GITHUB_REPO"] = ""
    GitRepoPatch.always
  ensure
    ENV["CODEBERG_REPO"] = codeberg
    ENV["GITHUB_REPO"] = github
  end

  def test_pushes_configured_repository
    github = ENV["GITHUB_REPO"]
    ENV["CODEBERG_REPO"] = "git@example.com:repo.git"
    ENV["GITHUB_REPO"] = ""
    Cmd.expects(:local).with(includes("git remote remove codeberg")).raises("missing")
    Cmd.expects(:local).with(includes("git remote add codeberg git@example.com:repo.git"))
    Cmd.expects(:local).with(includes("git push codeberg master"))

    GitRepoPatch.always
  ensure
    ENV["CODEBERG_REPO"] = "ssh://git@codeberg.org/example/app.git"
    ENV["GITHUB_REPO"] = github
  end
end
