import JSZip from "jszip";

import {
  createChapter,
  createProject,
  createScene,
  updateSceneContent,
  updateSceneTitle
} from "../db/repositories";
import { createDocumentFromPlainText } from "../lib/editorContent";

interface ImportedSection {
  chapterNumber: number;
  sceneTitle: string | null;
  bodyParagraphs: string[];
}

export async function importScrivenerDocx(
  file: File,
  ownerUserId: string | null
): Promise<{ projectId: string }> {
  const sections = await parseScrivenerDocx(file);
  const projectTitle = file.name.replace(/\.docx$/i, "").trim() || "Imported Novel";
  const project = await createProject(projectTitle, ownerUserId);

  if (sections.length === 0) {
    const chapter = await createChapter(project.id, null);
    const scene = await createScene(project.id, chapter.id, null);
    return { projectId: project.id };
  }

  let insertAfterOrder: number | null = null;
  for (const [index, section] of sections.entries()) {
    const chapter = await createChapter(project.id, insertAfterOrder);
    const scene = await createScene(project.id, chapter.id, null);
    const sceneTitle = section.sceneTitle?.trim() ? section.sceneTitle.trim() : "Scene 1";
    const plainText = normalizeImportedBody(section.bodyParagraphs);

    if (sceneTitle !== scene.title) {
      await updateSceneTitle(scene.id, sceneTitle);
    }

    if (plainText.length > 0) {
      await updateSceneContent(scene.id, createDocumentFromPlainText(plainText), plainText, 0, 0);
    }

    insertAfterOrder = index;
  }

  return { projectId: project.id };
}

async function parseScrivenerDocx(file: File): Promise<ImportedSection[]> {
  const zip = await JSZip.loadAsync(await file.arrayBuffer());
  const documentXml = await zip.file("word/document.xml")?.async("string");
  if (!documentXml) {
    throw new Error("This DOCX file does not contain a readable document body.");
  }

  const parser = new DOMParser();
  const xml = parser.parseFromString(documentXml, "application/xml");
  const paragraphNodes = Array.from(xml.getElementsByTagNameNS("*", "p"));

  const sections: ImportedSection[] = [];
  let currentSection: ImportedSection | null = null;

  for (const paragraphNode of paragraphNodes) {
    const text = extractParagraphText(paragraphNode).trim();

    if (text.length === 0) {
      if (currentSection && currentSection.bodyParagraphs[currentSection.bodyParagraphs.length - 1] !== "") {
        currentSection.bodyParagraphs.push("");
      }
      continue;
    }

    const heading = parseHeading(text);
    if (heading) {
      if (currentSection) {
        sections.push(currentSection);
      }

      currentSection = {
        chapterNumber: heading.number,
        sceneTitle: heading.subtitle,
        bodyParagraphs: []
      };
      continue;
    }

    if (!currentSection) {
      currentSection = {
        chapterNumber: 1,
        sceneTitle: null,
        bodyParagraphs: []
      };
    }

    currentSection.bodyParagraphs.push(text);
  }

  if (currentSection) {
    sections.push(currentSection);
  }

  return sections;
}

function extractParagraphText(paragraphNode: Element): string {
  const fragments: string[] = [];

  for (const child of Array.from(paragraphNode.childNodes)) {
    if (child.nodeType !== Node.ELEMENT_NODE) {
      continue;
    }

    const element = child as Element;
    if (element.localName === "r") {
      for (const runChild of Array.from(element.childNodes)) {
        if (runChild.nodeType !== Node.ELEMENT_NODE) {
          continue;
        }

        const runElement = runChild as Element;
        if (runElement.localName === "t") {
          fragments.push(runElement.textContent ?? "");
        } else if (runElement.localName === "tab") {
          fragments.push(" ");
        } else if (runElement.localName === "br") {
          fragments.push("\n");
        }
      }
    }
  }

  return fragments.join("").replace(/\u00a0/g, " ");
}

function parseHeading(text: string): { number: number; subtitle: string | null } | null {
  const normalizedText = normalizeHeadingText(text);
  const match = normalizedText.match(/^\s*(chapter|episode)\s+(\d+)\s*(?:[-,:]\s*(.+))?\s*$/i);
  if (!match) {
    return null;
  }

  return {
    number: Number.parseInt(match[2] ?? "1", 10),
    subtitle: match[3]?.trim() || null
  };
}

function normalizeHeadingText(text: string): string {
  return text
    .replace(/[\u2012\u2013\u2014\u2015]/g, "-")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizeImportedBody(paragraphs: string[]): string {
  const lines = [...paragraphs];

  while (lines[0] === "") {
    lines.shift();
  }
  while (lines.length > 0 && lines[lines.length - 1] === "") {
    lines.pop();
  }

  return lines.join("\n\n");
}
