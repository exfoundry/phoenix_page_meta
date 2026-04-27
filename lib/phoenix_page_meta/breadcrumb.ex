defmodule PhoenixPageMeta.Breadcrumb do
  @moduledoc """
  A single entry in a breadcrumb trail, plus the builder.

  ## Struct fields

    * `:title` — the resolved breadcrumb title (`:breadcrumb_title` from the
      source page, falling back to `:title`).
    * `:path` — the page path, copied from the source.
    * `:first?` — `true` for the first item in the visible trail.
    * `:last?` — `true` for the current page (last item in the visible trail).
    * `:page_meta` — the original PageMeta struct, for access to project-
      specific fields like `:icon`.

  ## Building

      PhoenixPageMeta.Breadcrumb.build(page_meta)
      # most projects call via the wrapper:
      MyAppWeb.PageMeta.breadcrumbs(page_meta)

  Walks the `:parent` chain from the current page to the root, returns a list
  of `%PhoenixPageMeta.Breadcrumb{}` structs in root-first order.

  Pages with `:skip_breadcrumb` set to `true` are filtered from the list. This
  is useful for modal or overlay routes that should not appear as a stack
  push — the breadcrumb shows the underlying page as the current one.

  ## Rendering

  Use `PhoenixPageMeta.Components.Breadcrumbs.list/1` for accessible markup
  with slot-based styling.
  """

  @enforce_keys [:title, :path, :first?, :last?, :page_meta]
  defstruct [:title, :path, :first?, :last?, :page_meta]

  @type t :: %__MODULE__{
          title: String.t(),
          path: String.t(),
          first?: boolean(),
          last?: boolean(),
          page_meta: struct()
        }

  @doc """
  Builds a breadcrumb trail from a PageMeta struct.

  Walks the `:parent` chain, filters out pages with `:skip_breadcrumb` set,
  and returns root-first list of `%PhoenixPageMeta.Breadcrumb{}`.

  Raises if any parent in the chain has a `nil` path.
  """
  @spec build(struct()) :: [t()]
  def build(page_meta) when is_struct(page_meta) do
    page_meta
    |> Stream.iterate(fn page ->
      case page.parent do
        nil -> nil
        %_{path: nil} -> raise ArgumentError, "parent breadcrumb is missing :path"
        parent -> parent
      end
    end)
    |> Stream.take_while(& &1)
    |> Enum.reject(&Map.get(&1, :skip_breadcrumb, false))
    |> Enum.reverse()
    |> wrap()
  end

  defp wrap([]), do: []

  defp wrap(pages) do
    last_index = length(pages) - 1

    pages
    |> Enum.with_index()
    |> Enum.map(fn {page, index} ->
      %__MODULE__{
        title: Map.get(page, :breadcrumb_title) || page.title,
        path: page.path,
        first?: index == 0,
        last?: index == last_index,
        page_meta: page
      }
    end)
  end
end
