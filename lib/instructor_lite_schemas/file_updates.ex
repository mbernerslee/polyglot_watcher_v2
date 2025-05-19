defmodule PolyglotWatcherV2.InstructorLiteSchemas.CodeFileUpdate do
  use Ecto.Schema
  use InstructorLite.Instruction

  @primary_key false
  embedded_schema do
    field :file_path, :string
    field :explanation, :string
    field :search, :string
    field :replace, :string
  end
end

defmodule PolyglotWatcherV2.InstructorLiteSchemas.CodeFileUpdates do
  use Ecto.Schema
  use InstructorLite.Instruction

  alias PolyglotWatcherV2.InstructorLiteSchemas.CodeFileUpdate

  @primary_key false
  embedded_schema do
    embeds_many :updates, CodeFileUpdate
  end
end
