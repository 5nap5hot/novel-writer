import { Extension } from "@tiptap/core";
import Color from "@tiptap/extension-color";
import TextAlign from "@tiptap/extension-text-align";
import TextStyle from "@tiptap/extension-text-style";
import Underline from "@tiptap/extension-underline";
import StarterKit from "@tiptap/starter-kit";
import {
  getFontSizeStyle,
  getLineSpacingStyle,
  type FontSizePreset,
  type LineSpacingPreset
} from "../../lib/editorContent";

declare module "@tiptap/core" {
  interface Commands<ReturnType> {
    fontSize: {
      setFontSize: (fontSize: FontSizePreset) => ReturnType;
      unsetFontSize: () => ReturnType;
    };
    lineHeight: {
      setLineHeight: (lineHeight: LineSpacingPreset) => ReturnType;
      unsetLineHeight: () => ReturnType;
    };
  }
}

export const FontSize = Extension.create({
  name: "fontSize",
  addGlobalAttributes() {
    return [
      {
        types: ["textStyle"],
        attributes: {
          fontSize: {
            default: null,
            parseHTML: () => null,
            renderHTML: (attributes) => {
              const styleValue = getFontSizeStyle(attributes.fontSize as FontSizePreset | null | undefined);
              if (!styleValue) {
                return {};
              }

              return {
                style: `font-size: ${styleValue}`
              };
            }
          }
        }
      }
    ];
  },
  addCommands() {
    return {
      setFontSize:
        (fontSize) =>
        ({ chain }) =>
          chain().setMark("textStyle", { fontSize }).run(),
      unsetFontSize:
        () =>
        ({ chain }) =>
          chain().setMark("textStyle", { fontSize: null }).removeEmptyTextStyle().run()
    };
  }
});

export const LineHeight = Extension.create({
  name: "lineHeight",
  addGlobalAttributes() {
    return [
      {
        types: ["paragraph"],
        attributes: {
          lineHeight: {
            default: null,
            parseHTML: () => null,
            renderHTML: (attributes) => {
              const styleValue = getLineSpacingStyle(
                attributes.lineHeight as LineSpacingPreset | null | undefined
              );
              if (!styleValue) {
                return {};
              }

              return {
                style: `line-height: ${styleValue}`
              };
            }
          }
        }
      }
    ];
  },
  addCommands() {
    return {
      setLineHeight:
        (lineHeight) =>
        ({ chain }) =>
          chain().updateAttributes("paragraph", { lineHeight }).run(),
      unsetLineHeight:
        () =>
        ({ chain }) =>
          chain().updateAttributes("paragraph", { lineHeight: null }).run()
    };
  }
});

export const EditorShortcuts = Extension.create({
  name: "editorShortcuts",
  addKeyboardShortcuts() {
    return {
      "Mod-b": () => this.editor.chain().focus().toggleBold().run(),
      "Mod-i": () => this.editor.chain().focus().toggleItalic().run(),
      "Mod-u": () => this.editor.chain().focus().toggleUnderline().run(),
      "Mod-Shift-7": () => this.editor.chain().focus().toggleBulletList().run(),
      "Mod-z": () => this.editor.chain().focus().undo().run(),
      "Mod-Shift-z": () => this.editor.chain().focus().redo().run()
    };
  }
});

export const editorExtensions = [
  StarterKit.configure({
    heading: false,
    blockquote: false,
    code: false,
    codeBlock: false,
    hardBreak: false,
    horizontalRule: false,
    orderedList: false,
    strike: false
  }),
  Underline,
  TextStyle,
  Color,
  FontSize,
  EditorShortcuts,
  TextAlign.configure({
    types: ["paragraph"],
    alignments: ["left", "center", "right", "justify"],
    defaultAlignment: "left"
  }),
  LineHeight
];
