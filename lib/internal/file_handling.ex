defmodule Babel.FileHandling do
  @moduledoc """
  Handles the collection and reading of SQL files for Babel.

  Uses the pattern configured in `:sql_path_pattern` (default: `lib/**/*.sql`)
  to find and read SQL files in the project.
  """

  defmodule SqlFile do
    @moduledoc """
    Represents a raw SQL file and its contents in Babel.
    """

    @type t :: %__MODULE__{
            path: String.t(),
            name: String.t(),
            content: String.t()
          }

    @enforce_keys [:path, :name, :content]
    defstruct [:path, :name, :content]
  end

  @default_pattern "lib/**/*.sql"

  @doc """
  Collects all SQL files matching the configured pattern.

  Returns a list of SqlFile structs containing the relative path, name, and content
  of each SQL file found.
  """
  @spec collect_sql_files!() :: [SqlFile.t()]
  def collect_sql_files!, do: collect_sql_files!(project_root())

  @spec collect_sql_files!(String.t()) :: [SqlFile.t()]
  def collect_sql_files!(root) do
    collect(root)
    |> read_all!(root)
  end

  @spec collect(String.t()) :: [String.t()]
  defp collect(root) do
    pattern = Application.get_env(:babel, :sql_path_pattern, @default_pattern)
    dir_glob = Path.join(root, pattern)
    Path.wildcard(dir_glob)
  end

  @spec read_all!([String.t()], String.t()) :: [SqlFile.t()]
  defp read_all!(path_set, root) do
    path_set
    |> Enum.map(&read!(&1, root))
  end

  @spec read!(String.t(), String.t()) :: SqlFile.t()
  defp read!(path, root) do
    case File.read(path) do
      {:ok, content} ->
        %SqlFile{
          path: Path.relative_to(path, root),
          name: Path.basename(path, ".sql"),
          content: content
        }

      {:error, reason} ->
        # TODO: We will want to centralise the error handling but that needs more planning so for now: 
        raise "The SQL file at '#{path}' could not be loaded for the following reason: #{IO.inspect(reason)}"
    end
  end

  @spec project_root() :: String.t()
  defp project_root do
    if Mix.Project.get() do
      mix_file = Mix.Project.project_file()
      Path.dirname(mix_file)
    else
      File.cwd!()
    end
  end
end
