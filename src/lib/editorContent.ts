import type { RichTextContent } from "../types/models";

export const FONT_SIZE_PRESETS = {
  sm: "0.864em",
  md: "1em",
  lg: "1.182em",
  xl: "1.409em"
} as const;

export const LINE_SPACING_PRESETS = {
  normal: "1",
  relaxed: "1.5",
  double: "2"
} as const;

export type FontSizePreset = keyof typeof FONT_SIZE_PRESETS;
export type LineSpacingPreset = keyof typeof LINE_SPACING_PRESETS;
export type TextAlignment = "left" | "center" | "right" | "justify";

const ALLOWED_NODE_TYPES = new Set(["doc", "paragraph", "text", "bulletList", "listItem"]);
const ALLOWED_MARK_TYPES = new Set(["bold", "italic", "underline", "textStyle"]);
const ALLOWED_ALIGNMENTS = new Set<TextAlignment>(["left", "center", "right", "justify"]);
const COLOR_HEX_PATTERN = /^#([0-9a-f]{6})$/i;

export const EMPTY_DOCUMENT: RichTextContent = {
  type: "doc",
  content: [
    {
      type: "paragraph"
    }
  ]
};

export interface TextMetrics {
  plainText: string;
  wordCount: number;
  characterCount: number;
}

export function createDocumentFromPlainText(text: string): RichTextContent {
  const blocks = text.split(/\n{2,}/).map((line) => line.trimEnd());

  return sanitizeRichTextContent({
    type: "doc",
    content: blocks.length > 0
      ? blocks.map((block) => ({
          type: "paragraph",
          content: block
            ? [
                {
                  type: "text",
                  text: block
                }
              ]
            : []
        }))
      : [{ type: "paragraph" }]
  });
}

export function sanitizeRichTextContent(
  input: RichTextContent | null | undefined
): RichTextContent {
  const sanitized = sanitizeNode(input);

  if (!sanitized || sanitized.type !== "doc") {
    return structuredCloneSafe(EMPTY_DOCUMENT);
  }

  return {
    type: "doc",
    content:
      sanitized.content && sanitized.content.length > 0
        ? sanitized.content
        : structuredCloneSafe(EMPTY_DOCUMENT).content
  };
}

export function extractPlainText(content: RichTextContent | null | undefined): string {
  const sanitized = sanitizeRichTextContent(content);
  const blocks = (sanitized.content ?? [])
    .map((node) => extractTextFromNode(node))
    .filter((block) => block.length > 0);

  return blocks.join("\n\n");
}

export function getTextMetrics(content: RichTextContent | null | undefined): TextMetrics {
  const plainText = extractPlainText(content)
    .replace(/\u00a0/g, " ")
    .replace(/[ \t]+\n/g, "\n")
    .trim();
  const wordCount = plainText.length === 0
    ? 0
    : plainText.split(/\s+/).filter(Boolean).length;
  const characterCount = plainText.length;

  return {
    plainText,
    wordCount,
    characterCount
  };
}

export function normalizeRichTextContent(
  scene: Pick<{
    contentJson?: RichTextContent;
    contentText?: string;
    content?: string;
  }, "contentJson" | "contentText" | "content">
): RichTextContent {
  if (scene.contentJson) {
    return sanitizeRichTextContent(scene.contentJson);
  }

  if (scene.contentText && scene.contentText.trim().length > 0) {
    return createDocumentFromPlainText(scene.contentText);
  }

  if (scene.content && scene.content.trim().length > 0) {
    return createDocumentFromPlainText(scene.content);
  }

  return structuredCloneSafe(EMPTY_DOCUMENT);
}

export function getFontSizeStyle(value: FontSizePreset | null | undefined): string | null {
  return value ? FONT_SIZE_PRESETS[value] ?? null : null;
}

export function getLineSpacingStyle(
  value: LineSpacingPreset | null | undefined
): string | null {
  return value ? LINE_SPACING_PRESETS[value] ?? null : null;
}

function sanitizeNode(node: RichTextContent | null | undefined): RichTextContent | null {
  if (!node?.type) {
    return null;
  }

  if (!ALLOWED_NODE_TYPES.has(node.type)) {
    if (node.type === "orderedList") {
      const listItems = (node.content ?? [])
        .map((child) => sanitizeNode({ ...child, type: "listItem" }))
        .filter((child): child is RichTextContent => child !== null);

      return listItems.length > 0
        ? {
            type: "bulletList",
            content: listItems
          }
        : null;
    }

    if (node.type === "hardBreak") {
      return {
        type: "text",
        text: "\n"
      };
    }

    const fallbackInlineContent = collectInlineTextContent(node);
    return fallbackInlineContent.length > 0
      ? {
          type: "paragraph",
          content: fallbackInlineContent
        }
      : null;
  }

  if (node.type === "text") {
    if (typeof node.text !== "string" || node.text.length === 0) {
      return null;
    }

    const sanitizedMarks = sanitizeMarks(node.attrs, (node as RichTextContent & {
      marks?: RichTextContent[];
    }).marks);

    return {
      type: "text",
      text: node.text,
      ...(sanitizedMarks.length > 0 ? { marks: sanitizedMarks } : {})
    } as RichTextContent;
  }

  const sanitizedContent = (node.content ?? [])
    .map((child) => sanitizeNode(child))
    .filter((child): child is RichTextContent => child !== null);

  if (node.type === "listItem" && sanitizedContent.length === 0) {
    sanitizedContent.push({ type: "paragraph" });
  }

  const attrs = sanitizeNodeAttributes(node.type, node.attrs);

  return {
    type: node.type,
    ...(Object.keys(attrs).length > 0 ? { attrs } : {}),
    ...(sanitizedContent.length > 0 ? { content: sanitizedContent } : {})
  };
}

function sanitizeNodeAttributes(
  type: string,
  attrs: Record<string, unknown> | undefined
): Record<string, unknown> {
  if (!attrs) {
    return {};
  }

  const next: Record<string, unknown> = {};

  if (type === "paragraph") {
    if (typeof attrs.textAlign === "string" && ALLOWED_ALIGNMENTS.has(attrs.textAlign as TextAlignment)) {
      next.textAlign = attrs.textAlign;
    }

    if (typeof attrs.lineHeight === "string" && attrs.lineHeight in LINE_SPACING_PRESETS) {
      next.lineHeight = attrs.lineHeight;
    }
  }

  return next;
}

function sanitizeMarks(
  _attrs: Record<string, unknown> | undefined,
  marks: Array<RichTextContent & { type?: string; attrs?: Record<string, unknown> }> | undefined
): Array<RichTextContent & { type: string }> {
  if (!marks) {
    return [];
  }

  return marks
    .filter((mark): mark is RichTextContent & { type: string; attrs?: Record<string, unknown> } =>
      Boolean(mark?.type && ALLOWED_MARK_TYPES.has(mark.type))
    )
    .map((mark) => {
      if (mark.type !== "textStyle") {
        return { type: mark.type };
      }

      const nextAttrs: Record<string, unknown> = {};
      const fontSize = mark.attrs?.fontSize;
      const color = mark.attrs?.color;

      if (typeof fontSize === "string" && fontSize in FONT_SIZE_PRESETS) {
        nextAttrs.fontSize = fontSize;
      }

      if (typeof color === "string" && COLOR_HEX_PATTERN.test(color)) {
        nextAttrs.color = color.toLowerCase();
      }

      return Object.keys(nextAttrs).length > 0
        ? { type: "textStyle", attrs: nextAttrs }
        : { type: "textStyle" };
    })
    .filter((mark) => mark.type !== "textStyle" || Boolean(mark.attrs && Object.keys(mark.attrs).length > 0));
}

function extractTextFromNode(node: RichTextContent): string {
  if (node.type === "text") {
    return typeof node.text === "string" ? node.text : "";
  }

  if (node.type === "bulletList") {
    return (node.content ?? [])
      .map((child) => extractTextFromNode(child))
      .filter(Boolean)
      .join("\n");
  }

  if (node.type === "listItem") {
    return (node.content ?? [])
      .map((child) => extractTextFromNode(child))
      .filter(Boolean)
      .join("\n");
  }

  return (node.content ?? [])
    .map((child) => extractTextFromNode(child))
    .filter(Boolean)
    .join("");
}

function structuredCloneSafe<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function collectInlineTextContent(node: RichTextContent): RichTextContent[] {
  if (node.type === "text" && typeof node.text === "string" && node.text.length > 0) {
    const sanitized = sanitizeNode(node);
    return sanitized ? [sanitized] : [];
  }

  return (node.content ?? []).flatMap((child) => collectInlineTextContent(child));
}
