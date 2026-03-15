import { Extension } from "@tiptap/core";
import { Plugin, PluginKey } from "@tiptap/pm/state";
import { Decoration, DecorationSet } from "@tiptap/pm/view";

export interface SearchHighlightRange {
  from: number;
  to: number;
}

interface SearchHighlightState {
  ranges: SearchHighlightRange[];
  currentIndex: number | null;
}

const SEARCH_HIGHLIGHT_PLUGIN_KEY = new PluginKey<SearchHighlightState>("novelWriterSearchHighlights");

declare module "@tiptap/core" {
  interface Commands<ReturnType> {
    searchHighlights: {
      setSearchHighlights: (
        ranges: SearchHighlightRange[],
        currentIndex: number | null
      ) => ReturnType;
      clearSearchHighlights: () => ReturnType;
    };
  }
}

export const SearchHighlightExtension = Extension.create({
  name: "searchHighlights",
  addCommands() {
    return {
      setSearchHighlights:
        (ranges, currentIndex) =>
        ({ tr, dispatch }) => {
          if (!dispatch) {
            return true;
          }

          dispatch(
            tr.setMeta(SEARCH_HIGHLIGHT_PLUGIN_KEY, {
              ranges,
              currentIndex
            } satisfies SearchHighlightState)
          );
          return true;
        },
      clearSearchHighlights:
        () =>
        ({ tr, dispatch }) => {
          if (!dispatch) {
            return true;
          }

          dispatch(
            tr.setMeta(SEARCH_HIGHLIGHT_PLUGIN_KEY, {
              ranges: [],
              currentIndex: null
            } satisfies SearchHighlightState)
          );
          return true;
        }
    };
  },
  addProseMirrorPlugins() {
    return [
      new Plugin<SearchHighlightState>({
        key: SEARCH_HIGHLIGHT_PLUGIN_KEY,
        state: {
          init: () => ({
            ranges: [],
            currentIndex: null
          }),
          apply(tr, value) {
            return (tr.getMeta(SEARCH_HIGHLIGHT_PLUGIN_KEY) as SearchHighlightState | undefined) ?? value;
          }
        },
        props: {
          decorations(state) {
            const pluginState = SEARCH_HIGHLIGHT_PLUGIN_KEY.getState(state);
            if (!pluginState || pluginState.ranges.length === 0) {
              return null;
            }

            return DecorationSet.create(
              state.doc,
              pluginState.ranges.map((range, index) =>
                Decoration.inline(range.from, range.to, {
                  class:
                    index === pluginState.currentIndex
                      ? "search-highlight search-highlight-current"
                      : "search-highlight"
                })
              )
            );
          }
        }
      })
    ];
  }
});
