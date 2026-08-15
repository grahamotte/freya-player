class GitRepoPatch < BasePatch
  class << self
    def always
      push_to("codeberg", Constants.codeberg_repo)
      push_to("github", Constants.github_repo)
    end

    private

    def push_to(remote, repo)
      return if repo.to_s.strip.empty?

      Cmd.local("GIT_SSH_COMMAND='ssh -i #{Constants.ssh_key_path}' git remote remove #{remote}") rescue StandardError
      Cmd.local("GIT_SSH_COMMAND='ssh -i #{Constants.ssh_key_path}' git remote add #{remote} #{repo}")
      Cmd.local("GIT_SSH_COMMAND='ssh -i #{Constants.ssh_key_path}' git push #{remote} master")
    end
  end
end
