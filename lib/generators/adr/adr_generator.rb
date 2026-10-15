class AdrGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  desc "Creates a numbered Architecture Decision Record in docs/adr/"

  argument :title, type: :string, desc: "Decision title, e.g. \"Use Solid Queue for background jobs\""
  class_option :status, type: :string, default: "Proposed", desc: "Initial status (Proposed, Accepted, ...)"

  ADR_DIR = "docs/adr"

  def create_adr
    template "adr.md.tt", File.join(ADR_DIR, "#{padded_number}-#{title.parameterize}.md")
  end

  private
    def number
      @number ||= Dir.glob(File.join(destination_root, ADR_DIR, "[0-9][0-9][0-9][0-9]-*.md"))
        .map { |path| File.basename(path).to_i }
        .max.to_i + 1
    end

    def padded_number
      format("%04d", number)
    end
end
