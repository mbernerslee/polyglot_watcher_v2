defmodule PolyglotWatcherV2.AccessBehaviour do
  @doc """
    Provides default Access behaviour implementation for structs.

    e.g. allows the following

    updated_file = put_in(file, [:test, :failed_line_numbers], [15, 25])
    updated_file = update_in(file, [:rank], &(&1 + 1))

  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Access

      @impl Access
      def fetch(struct, key) do
        Map.fetch(struct, key)
      end

      @impl Access
      def get_and_update(struct, key, fun) do
        Map.get_and_update(struct, key, fun)
      end

      @impl Access
      def pop(struct, key) do
        Map.pop(struct, key)
      end
    end
  end
end
