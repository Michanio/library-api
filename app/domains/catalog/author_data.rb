module Catalog
  # An author as exposed by the Catalog public interface.
  AuthorData = Data.define(:id, :name) do
    def self.from(author)
      new(id: author.id, name: author.name)
    end
  end
end
