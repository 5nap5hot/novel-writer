import JSZip from "jszip";
import {
  AlignmentType,
  Document,
  HeadingLevel,
  Packer,
  Paragraph,
  TextRun
} from "docx";

import { getProjectBundle } from "../db/repositories";
import {
  getFontSizeStyle,
  getLineSpacingStyle,
  sanitizeRichTextContent,
  type LineSpacingPreset,
  type TextAlignment
} from "../lib/editorContent";
import type { ChapterRecord, RichTextContent, SceneRecord } from "../types/models";

export async function exportProjectSafetyZip(projectId: string): Promise<void> {
  const bundle = await getRequiredProjectBundle(projectId);
  const zip = new JSZip();
  const rootFolder = zip.folder(sanitizeFilename(bundle.project.title) || "Novel Writer")!;

  for (const chapter of bundle.chapters) {
    const chapterFolder = rootFolder.folder(`Chapter ${formatOrdinal(chapter.order + 1)}`)!;
    const chapterScenes = bundle.scenes
      .filter((scene) => scene.chapterId === chapter.id)
      .sort((left, right) => left.order - right.order);

    for (const scene of chapterScenes) {
      chapterFolder.file(
        `Scene ${formatOrdinal(scene.order + 1)}.md`,
        buildSceneMarkdown(chapter, scene)
      );
    }
  }

  const zipBlob = await zip.generateAsync({ type: "blob" });
  downloadBlob(
    zipBlob,
    `${sanitizeFilename(bundle.project.title) || "Novel Writer"} - safety export.zip`
  );
}

export async function exportProjectScrivenerDocx(projectId: string): Promise<void> {
  const bundle = await getRequiredProjectBundle(projectId);
  const children: Paragraph[] = [];

  for (const chapter of bundle.chapters) {
    children.push(
      new Paragraph({
        text: chapter.title,
        heading: HeadingLevel.HEADING_1
      })
    );

    const chapterScenes = bundle.scenes
      .filter((scene) => scene.chapterId === chapter.id)
      .sort((left, right) => left.order - right.order);

    for (const scene of chapterScenes) {
      children.push(
        new Paragraph({
          text: scene.title,
          heading: HeadingLevel.HEADING_2
        })
      );

      const sceneParagraphs = buildDocxParagraphs(scene.contentJson);
      if (sceneParagraphs.length > 0) {
        children.push(...sceneParagraphs);
      } else {
        children.push(new Paragraph(""));
      }
    }
  }

  const document = new Document({
    sections: [
      {
        children
      }
    ]
  });

  const docBlob = await Packer.toBlob(document);
  downloadBlob(
    docBlob,
    `${sanitizeFilename(bundle.project.title) || "Novel Writer"} - manuscript.docx`
  );
}

function buildSceneMarkdown(chapter: ChapterRecord, scene: SceneRecord): string {
  const body = richTextToMarkdown(scene.contentJson).trim();

  return [
    `# ${scene.title}`,
    "",
    `Chapter: ${chapter.title}`,
    "",
    body.length > 0 ? body : "_Empty scene_",
    ""
  ].join("\n");
}

function richTextToMarkdown(content: RichTextContent): string {
  const sanitized = sanitizeRichTextContent(content);
  const blocks = (sanitized.content ?? [])
    .flatMap((node) => renderMarkdownBlock(node))
    .filter((block) => block.trim().length > 0);

  return blocks.join("\n\n");
}

function renderMarkdownBlock(node: RichTextContent): string[] {
  if (node.type === "paragraph") {
    const text = renderMarkdownInline(node.content ?? []).trim();
    return text.length > 0 ? [text] : [];
  }

  if (node.type === "bulletList") {
    return (node.content ?? [])
      .flatMap((child) => renderMarkdownListItem(child))
      .filter((line) => line.trim().length > 0);
  }

  if (node.type === "listItem") {
    return renderMarkdownListItem(node);
  }

  return [];
}

function renderMarkdownListItem(node: RichTextContent): string[] {
  const paragraphs = (node.content ?? [])
    .filter((child) => child.type === "paragraph")
    .map((child) => renderMarkdownInline(child.content ?? []).trim())
    .filter((entry) => entry.length > 0);

  return paragraphs.map((paragraph, index) =>
    index === 0 ? `- ${paragraph}` : `  ${paragraph}`
  );
}

function renderMarkdownInline(nodes: RichTextContent[]): string {
  return nodes
    .map((node) => {
      if (node.type !== "text") {
        return renderMarkdownInline(node.content ?? []);
      }

      const baseText = escapeMarkdownText(node.text ?? "");
      const marks = node.marks ?? [];
      const hasBold = marks.some((mark) => mark.type === "bold");
      const hasItalic = marks.some((mark) => mark.type === "italic");
      const hasUnderline = marks.some((mark) => mark.type === "underline");

      let wrapped = baseText;
      if (hasBold) {
        wrapped = `**${wrapped}**`;
      }
      if (hasItalic) {
        wrapped = `*${wrapped}*`;
      }
      if (hasUnderline) {
        wrapped = `<u>${wrapped}</u>`;
      }

      return wrapped;
    })
    .join("");
}

function buildDocxParagraphs(content: RichTextContent): Paragraph[] {
  const sanitized = sanitizeRichTextContent(content);
  const paragraphs: Paragraph[] = [];

  for (const node of sanitized.content ?? []) {
    if (node.type === "paragraph") {
      paragraphs.push(
        new Paragraph({
          children: buildDocxRuns(node.content ?? []),
          alignment: getDocxAlignment(node.attrs?.textAlign),
          spacing: getDocxSpacing(node.attrs?.lineHeight)
        })
      );
      continue;
    }

    if (node.type === "bulletList") {
      for (const listItem of node.content ?? []) {
        const listParagraphs = (listItem.content ?? []).filter((child) => child.type === "paragraph");
        for (const paragraph of listParagraphs) {
          paragraphs.push(
            new Paragraph({
              children: buildDocxRuns(paragraph.content ?? []),
              bullet: {
                level: 0
              },
              alignment: getDocxAlignment(paragraph.attrs?.textAlign),
              spacing: getDocxSpacing(paragraph.attrs?.lineHeight)
            })
          );
        }
      }
    }
  }

  return paragraphs;
}

function buildDocxRuns(nodes: RichTextContent[]): TextRun[] {
  return nodes.flatMap((node) => {
    if (node.type !== "text") {
      return buildDocxRuns(node.content ?? []);
    }

    const marks = node.marks ?? [];
    const textStyleMark = marks.find((mark) => mark.type === "textStyle");
    const color = typeof textStyleMark?.attrs?.color === "string"
      ? textStyleMark.attrs.color.replace("#", "")
      : undefined;

    return [
      new TextRun({
        text: node.text ?? "",
        bold: marks.some((mark) => mark.type === "bold"),
        italics: marks.some((mark) => mark.type === "italic"),
        underline: marks.some((mark) => mark.type === "underline") ? {} : undefined,
        color,
        size: getDocxFontSize(textStyleMark?.attrs?.fontSize)
      })
    ];
  });
}

function getDocxAlignment(
  value: unknown
): (typeof AlignmentType)[keyof typeof AlignmentType] | undefined {
  const alignment = value as TextAlignment | undefined;

  if (alignment === "center") {
    return AlignmentType.CENTER;
  }

  if (alignment === "right") {
    return AlignmentType.RIGHT;
  }

  if (alignment === "justify") {
    return AlignmentType.JUSTIFIED;
  }

  if (alignment === "left") {
    return AlignmentType.LEFT;
  }

  return undefined;
}

function getDocxSpacing(value: unknown): { line?: number } | undefined {
  const preset = value as LineSpacingPreset | undefined;
  const styleValue = getLineSpacingStyle(preset);
  if (!styleValue) {
    return undefined;
  }

  const numericValue = Number.parseFloat(styleValue);
  if (Number.isNaN(numericValue)) {
    return undefined;
  }

  return {
    line: Math.round(numericValue * 240)
  };
}

function getDocxFontSize(value: unknown): number | undefined {
  const styleValue = getFontSizeStyle(value as never);
  if (!styleValue) {
    return undefined;
  }

  const numericValue = Number.parseFloat(styleValue);
  if (Number.isNaN(numericValue)) {
    return undefined;
  }

  return Math.round(numericValue * 22);
}

function escapeMarkdownText(text: string): string {
  return text
    .replace(/\\/g, "\\\\")
    .replace(/([*_`[\]])/g, "\\$1");
}

function sanitizeFilename(value: string): string {
  return value
    .replace(/[<>:"/\\|?*\u0000-\u001f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 80);
}

function formatOrdinal(value: number): string {
  return value.toString().padStart(2, "0");
}

function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();

  window.setTimeout(() => {
    URL.revokeObjectURL(url);
  }, 0);
}

async function getRequiredProjectBundle(projectId: string) {
  const bundle = await getProjectBundle(projectId);
  if (!bundle) {
    throw new Error("Project not found for export.");
  }

  return bundle;
}
