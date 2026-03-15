import type { Editor } from "@tiptap/react";
import type { Node as ProseMirrorNode } from "@tiptap/pm/model";
import type { SceneRecord } from "../../types/models";

export type SearchScope = "selection" | "entire_project";
export type SearchMode = "contains" | "whole_word" | "starts_with" | "ends_with";

export interface SearchOptions {
  query: string;
  replaceText: string;
  scope: SearchScope;
  mode: SearchMode;
  ignoreCase: boolean;
  ignoreDiacritics: boolean;
}

export interface SceneSearchMatch {
  sceneId: string;
  ordinal: number;
  startIndex: number;
  endIndex: number;
}

export interface EditorSearchMatch extends SceneSearchMatch {
  from: number;
  to: number;
}

export function findMatchesInScenes(
  scenes: SceneRecord[],
  options: SearchOptions
): SceneSearchMatch[] {
  if (!options.query.trim()) {
    return [];
  }

  return scenes.flatMap((scene) =>
    findMatchesInText(scene.contentText ?? "", options).map((match, ordinal) => ({
      sceneId: scene.id,
      ordinal,
      startIndex: match.startIndex,
      endIndex: match.endIndex
    }))
  );
}

export function findMatchesInEditor(
  editor: Editor,
  sceneId: string,
  options: SearchOptions
): EditorSearchMatch[] {
  if (!options.query.trim()) {
    return [];
  }

  const searchableDocument = buildSearchableDocument(editor.state.doc);
  const rawMatches = findMatchesInText(searchableDocument.text, options);

  return rawMatches
    .map((match, ordinal) => {
      const from = searchableDocument.offsetMap[match.startIndex];
      const to =
        searchableDocument.offsetMap[match.endIndex - 1] !== undefined
          ? searchableDocument.offsetMap[match.endIndex - 1] + 1
          : undefined;
      if (from === undefined || to === undefined || from >= to) {
        return null;
      }

      return {
        sceneId,
        ordinal,
        startIndex: match.startIndex,
        endIndex: match.endIndex,
        from,
        to
      } satisfies EditorSearchMatch;
    })
    .filter((match): match is EditorSearchMatch => match !== null);
}

export function findSelectedText(editor: Editor | null): string {
  if (!editor || !editor.isFocused) {
    return "";
  }

  const { from, to } = editor.state.selection;
  if (from === to) {
    return "";
  }

  return editor.state.doc.textBetween(from, to, "\n\n", "\n").trim();
}

function findMatchesInText(
  text: string,
  options: SearchOptions
): Array<{ startIndex: number; endIndex: number }> {
  const normalizedText = normalizeSearchString(text, options.ignoreCase, options.ignoreDiacritics);
  const normalizedQuery = normalizeSearchString(options.query, options.ignoreCase, options.ignoreDiacritics).trim();

  if (!normalizedQuery) {
    return [];
  }

  return findWordBasedMatches(normalizedText, normalizedQuery, options.mode);
}

function findWordBasedMatches(text: string, query: string, mode: SearchMode) {
  const matches: Array<{ startIndex: number; endIndex: number }> = [];

  if (mode === "contains") {
    let fromIndex = 0;
    while (fromIndex <= text.length) {
      const foundAt = text.indexOf(query, fromIndex);
      if (foundAt === -1) {
        break;
      }

      matches.push({
        startIndex: foundAt,
        endIndex: foundAt + query.length
      });
      fromIndex = foundAt + Math.max(query.length, 1);
    }

    return matches;
  }

  for (const word of findWordRanges(text)) {
    const wordText = text.slice(word.startIndex, word.endIndex);
    if (!wordText) {
      continue;
    }

    if (mode === "whole_word" && wordText === query) {
      matches.push({
        startIndex: word.startIndex,
        endIndex: word.endIndex
      });
    }

    if (mode === "starts_with" && wordText.startsWith(query)) {
      matches.push({
        startIndex: word.startIndex,
        endIndex: word.startIndex + query.length
      });
    }

    if (mode === "ends_with" && wordText.endsWith(query)) {
      matches.push({
        startIndex: word.endIndex - query.length,
        endIndex: word.endIndex
      });
    }
  }

  return matches;
}

function normalizeSearchString(
  input: string,
  ignoreCase: boolean,
  ignoreDiacritics: boolean
): string {
  let value = input;

  if (ignoreDiacritics) {
    value = value.normalize("NFD").replace(/\p{Diacritic}/gu, "");
  }

  if (ignoreCase) {
    value = value.toLocaleLowerCase();
  }

  return value;
}

function buildSearchableDocument(doc: ProseMirrorNode): {
  text: string;
  offsetMap: number[];
} {
  const textParts: string[] = [];
  const offsets: number[] = [];
  doc.forEach((node, offset, index) => {
    if (index > 0) {
      appendSeparator("\n\n", textParts, offsets);
    }

    collectNodeText(node, offset, textParts, offsets);
  });

  return {
    text: textParts.join(""),
    offsetMap: offsets
  };
}

function collectNodeText(
  node: ProseMirrorNode,
  pos: number,
  textParts: string[],
  offsets: number[]
) {
  if (node.isText && node.text) {
    for (let index = 0; index < node.text.length; index += 1) {
      textParts.push(node.text[index]);
      offsets.push(pos + index);
    }
    return;
  }

  node.forEach((child, offset, index) => {
    const childPos = pos + offset + 1;

    if (node.type.name === "bulletList" && index > 0) {
      appendSeparator("\n", textParts, offsets);
    }

    if (node.type.name === "listItem" && index > 0) {
      appendSeparator("\n", textParts, offsets);
    }

    collectNodeText(child, childPos, textParts, offsets);
  });
}

function appendSeparator(separator: string, textParts: string[], offsets: number[]) {
  const referenceOffset = offsets[offsets.length - 1];

  for (const character of separator) {
    textParts.push(character);
    offsets.push(referenceOffset ?? 1);
  }
}

function findWordRanges(text: string): Array<{ startIndex: number; endIndex: number }> {
  const ranges: Array<{ startIndex: number; endIndex: number }> = [];
  let wordStart: number | null = null;

  for (let index = 0; index <= text.length; index += 1) {
    const character = text[index] ?? "";
    const isWordCharacter = Boolean(character) && !isWordBoundary(character);

    if (isWordCharacter && wordStart === null) {
      wordStart = index;
      continue;
    }

    if (!isWordCharacter && wordStart !== null) {
      ranges.push({
        startIndex: wordStart,
        endIndex: index
      });
      wordStart = null;
    }
  }

  return ranges;
}

function isWordBoundary(character: string): boolean {
  if (!character) {
    return true;
  }

  return !/[\p{L}\p{N}_]/u.test(character);
}
