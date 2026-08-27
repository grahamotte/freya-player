require "open3"

class Agent
  class << self
    def call(model: "opencode-go/deepseek-v4-flash", effort: "high", prompt:)
      new(model:, effort:, prompt:).call
    end
  end

  def initialize(model:, effort:, prompt:)
    @model = model
    @effort = effort
    @prompt = prompt
  end

  def call
    stdout, stderr, status = capture
    raise "Agent failed: #{stderr.strip.presence || stdout.strip.presence || "unknown error"}" unless status.success?

    stdout.each_line.filter_map do |line|
      event = JSON.parse(line)
      event.dig("part", "text") if event["type"] == "text"
    end
  end

  private

  def capture
    Open3.capture3(environment, *command, **options)
  end

  def environment = { "OPENCODE_API_KEY" => ENV.fetch("OPENCODE_TOKEN") }

  def options = { stdin_data: @prompt, chdir: Rails.root.to_s }

  def command
    [
      "opencode",
      "run",
      "--format",
      "json",
      "--model",
      @model,
      "--variant",
      @effort,
    ]
  end
end
