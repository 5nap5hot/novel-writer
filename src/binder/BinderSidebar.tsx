import {
  DndContext,
  DragOverlay,
  PointerSensor,
  useDraggable,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent
} from "@dnd-kit/core";
import {
  useEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type MouseEvent,
  type ReactNode
} from "react";

import type { ChapterRecord, ProjectRecord, SceneRecord, TrashItemRecord } from "../types/models";
import { InlineEditableText } from "../components/InlineEditableText";

type BinderSelectionMode = "single" | "toggle" | "range";
type DragItem =
  | { type: "chapter"; id: string }
  | { type: "scene"; id: string };

interface BinderSidebarProps {
  project: ProjectRecord;
  projectWordCount: number;
  chapters: ChapterRecord[];
  scenes: SceneRecord[];
  trashItems: TrashItemRecord[];
  selectedChapterId: string | null;
  selectedSceneId: string | null;
  selectedChapterIds: string[];
  selectedSceneIds: string[];
  selectedTrashItemId: string | null;
  expandedChapterIds: string[];
  onRenameProject: (title: string) => void;
  onRenameChapter: (chapterId: string, title: string) => void;
  onRenameScene: (sceneId: string, title: string) => void;
  onSelectChapter: (chapterId: string, mode: BinderSelectionMode) => void;
  onSelectScene: (sceneId: string, mode: BinderSelectionMode) => void;
  onToggleChapter: (chapterId: string) => void;
  onReorderChapters: (orderedChapterIds: string[]) => void;
  onMoveScene: (sceneId: string, targetChapterId: string, targetOrder: number) => void;
  onCreateChapter: () => void;
  onCreateScene: () => void;
  onDeleteChapter: (chapterId: string) => void;
  onDeleteScene: (sceneId: string) => void;
  onSelectTrashItem: (trashItemId: string) => void;
  onRestoreTrashItem: (trashItemId: string) => void;
  onPermanentDeleteTrashItem: (trashItemId: string) => void;
}

export function BinderSidebar({
  project,
  projectWordCount,
  chapters,
  scenes,
  trashItems,
  selectedChapterId,
  selectedSceneId,
  selectedChapterIds,
  selectedSceneIds,
  selectedTrashItemId,
  expandedChapterIds,
  onRenameProject,
  onRenameChapter,
  onRenameScene,
  onSelectChapter,
  onSelectScene,
  onToggleChapter,
  onReorderChapters,
  onMoveScene,
  onCreateChapter,
  onCreateScene,
  onDeleteChapter,
  onDeleteScene,
  onSelectTrashItem,
  onRestoreTrashItem,
  onPermanentDeleteTrashItem
}: BinderSidebarProps) {
  const [activeDragItem, setActiveDragItem] = useState<DragItem | null>(null);
  const [isTrashExpanded, setIsTrashExpanded] = useState(false);
  const scrollContainerRef = useRef<HTMLDivElement | null>(null);
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        distance: 6
      }
    })
  );

  function getSelectionMode(event: MouseEvent<HTMLButtonElement>): BinderSelectionMode {
    if (event.shiftKey) {
      return "range";
    }

    if (event.metaKey || event.ctrlKey) {
      return "toggle";
    }

    return "single";
  }

  const visibleItemKeys = useMemo(
    () =>
      chapters.flatMap((chapter) => {
        const chapterKey = `chapter:${chapter.id}`;
        if (!expandedChapterIds.includes(chapter.id)) {
          return [chapterKey];
        }

        const chapterScenes = scenes
          .filter((scene) => scene.chapterId === chapter.id)
          .sort((left, right) => left.order - right.order)
          .map((scene) => `scene:${scene.id}`);

        return [chapterKey, ...chapterScenes];
      }),
    [chapters, expandedChapterIds, scenes]
  );

  const selectedItemKey = selectedSceneId
    ? `scene:${selectedSceneId}`
    : selectedChapterId
      ? `chapter:${selectedChapterId}`
      : null;

  useEffect(() => {
    if (!selectedItemKey) {
      return;
    }

    rowRefs.current.get(selectedItemKey)?.scrollIntoView({
      block: "nearest"
    });
  }, [selectedItemKey]);

  function handleBinderKeyDown(event: KeyboardEvent<HTMLDivElement>) {
    const target = event.target as HTMLElement | null;
    if (
      target &&
      (target.tagName === "INPUT" ||
        target.tagName === "TEXTAREA" ||
        target.tagName === "SELECT" ||
        target.isContentEditable)
    ) {
      return;
    }

    const currentIndex = selectedItemKey ? visibleItemKeys.indexOf(selectedItemKey) : -1;

    if (event.key === "ArrowDown") {
      if (selectedChapterId && !selectedSceneId) {
        const firstScene = scenes
          .filter((scene) => scene.chapterId === selectedChapterId)
          .sort((left, right) => left.order - right.order)[0];
        if (firstScene) {
          event.preventDefault();
          void onSelectScene(firstScene.id, "single");
          return;
        }
      }

      const nextKey = visibleItemKeys[Math.min(currentIndex + 1, visibleItemKeys.length - 1)];
      if (!nextKey) {
        return;
      }

      event.preventDefault();
      const [itemType, itemId] = nextKey.split(":");
      if (itemType === "chapter") {
        void onSelectChapter(itemId, "single");
      } else {
        void onSelectScene(itemId, "single");
      }
      return;
    }

    if (event.key === "ArrowUp") {
      const nextKey = visibleItemKeys[Math.max(currentIndex - 1, 0)];
      if (!nextKey) {
        return;
      }

      event.preventDefault();
      const [itemType, itemId] = nextKey.split(":");
      if (itemType === "chapter") {
        void onSelectChapter(itemId, "single");
      } else {
        void onSelectScene(itemId, "single");
      }
      return;
    }

    if (event.key === "ArrowRight" && selectedChapterId && !selectedSceneId) {
      if (!expandedChapterIds.includes(selectedChapterId)) {
        event.preventDefault();
        void onToggleChapter(selectedChapterId);
      }
      return;
    }

    if (event.key === "ArrowLeft") {
      if (selectedSceneId) {
        const parentChapterId = scenes.find((scene) => scene.id === selectedSceneId)?.chapterId ?? null;
        if (parentChapterId) {
          event.preventDefault();
          void onSelectChapter(parentChapterId, "single");
        }
        return;
      }

      if (selectedChapterId && expandedChapterIds.includes(selectedChapterId)) {
        event.preventDefault();
        void onToggleChapter(selectedChapterId);
      }
      return;
    }

    if (event.key === "Enter") {
      if (selectedSceneId) {
        event.preventDefault();
        void onSelectScene(selectedSceneId, "single");
        return;
      }

      if (selectedChapterId) {
        const firstScene = scenes
          .filter((scene) => scene.chapterId === selectedChapterId)
          .sort((left, right) => left.order - right.order)[0];
        if (firstScene) {
          event.preventDefault();
          void onSelectScene(firstScene.id, "single");
        }
      }
    }
  }

  function handleDragStart(event: DragStartEvent) {
    const dragData = event.active.data.current as DragItem | undefined;
    if (dragData) {
      setActiveDragItem(dragData);
    }
  }

  function handleDragEnd(event: DragEndEvent) {
    const dragData = event.active.data.current as DragItem | undefined;
    const overId = typeof event.over?.id === "string" ? event.over.id : null;
    setActiveDragItem(null);

    if (!dragData || !overId) {
      return;
    }

    if (dragData.type === "chapter" && overId.startsWith("chapter-drop:")) {
      const orderedChapterIds = chapters.map((chapter) => chapter.id);
      const fromIndex = orderedChapterIds.indexOf(dragData.id);
      if (fromIndex === -1) {
        return;
      }

      const nextIds = orderedChapterIds.filter((chapterId) => chapterId !== dragData.id);
      const targetChapterId = overId.slice("chapter-drop:".length);
      const insertionIndex =
        targetChapterId === "end"
          ? nextIds.length
          : Math.max(0, nextIds.indexOf(targetChapterId));
      nextIds.splice(insertionIndex, 0, dragData.id);
      onReorderChapters(nextIds);
      return;
    }

    if (dragData.type === "scene") {
      if (overId.startsWith("scene-drop:")) {
        const [, chapterId, orderText] = overId.split(":");
        const targetOrder = Number(orderText);
        if (!Number.isNaN(targetOrder)) {
          onMoveScene(dragData.id, chapterId, targetOrder);
        }
        return;
      }

      if (overId.startsWith("scene-append:")) {
        const targetChapterId = overId.slice("scene-append:".length);
        const targetOrder = scenes.filter((scene) => scene.chapterId === targetChapterId).length;
        onMoveScene(dragData.id, targetChapterId, targetOrder);
      }
    }
  }

  return (
    <aside className="binder-sidebar">
      <div className="binder-toolbar">
        <span className="binder-project-word-count">
          Project: {projectWordCount.toLocaleString()} words
        </span>
        <div className="button-row">
          <button
            className="secondary-button binder-toolbar-button"
            onClick={onCreateChapter}
            aria-label="New chapter"
            title="New chapter"
          >
            <BinderIconFrame>
              <ChapterIcon />
            </BinderIconFrame>
          </button>
          <button
            className="secondary-button binder-toolbar-button"
            onClick={onCreateScene}
            disabled={!selectedChapterId}
            aria-label="New scene"
            title="New scene"
          >
            <BinderIconFrame>
              <SceneIcon />
            </BinderIconFrame>
          </button>
        </div>
      </div>

      <DndContext sensors={sensors} onDragStart={handleDragStart} onDragEnd={handleDragEnd}>
        <div
          ref={scrollContainerRef}
          className="binder-scroll-container"
          tabIndex={0}
          onKeyDown={handleBinderKeyDown}
          onMouseDownCapture={(event) => {
            const target = event.target as HTMLElement | null;
            if (
              target &&
              (target.tagName === "INPUT" ||
                target.tagName === "TEXTAREA" ||
                target.isContentEditable)
            ) {
              return;
            }

            scrollContainerRef.current?.focus();
          }}
        >
          <div className="binder-tree">
            <div className="binder-project">
              <div className="binder-row binder-row-static">
                <InlineEditableText
                  className="tree-input project-input"
                  value={project.title}
                  onCommit={onRenameProject}
                />
              </div>

              <div className="binder-children">
                <ChapterDropZone id="chapter-drop:start" isActive={activeDragItem?.type === "chapter"} />
                {chapters.map((chapter, chapterIndex) => {
                  const chapterScenes = scenes
                    .filter((scene) => scene.chapterId === chapter.id)
                    .sort((left, right) => left.order - right.order);
                  const isExpanded = expandedChapterIds.includes(chapter.id);
                  const isSelected =
                    selectedChapterIds.includes(chapter.id) || selectedChapterId === chapter.id;

                  return (
                    <div key={chapter.id} className="binder-chapter">
                      {chapterIndex > 0 ? (
                        <ChapterDropZone
                          id={`chapter-drop:${chapter.id}`}
                          isActive={activeDragItem?.type === "chapter"}
                        />
                      ) : null}
                      <DraggableBinderRow
                        id={`chapter:${chapter.id}`}
                        dragItem={{ type: "chapter", id: chapter.id }}
                        rowRef={(element) => {
                          if (element) {
                            rowRefs.current.set(`chapter:${chapter.id}`, element);
                          } else {
                            rowRefs.current.delete(`chapter:${chapter.id}`);
                          }
                        }}
                        className={isSelected ? "is-selected" : ""}
                      >
                        <button
                          className="tree-toggle"
                          onClick={() => onToggleChapter(chapter.id)}
                          aria-label={isExpanded ? "Collapse chapter" : "Expand chapter"}
                        >
                          {isExpanded ? "−" : "+"}
                        </button>
                        <SceneAppendDropTarget chapterId={chapter.id} isActive={activeDragItem?.type === "scene"}>
                          <button
                            className="chapter-hit-area"
                            onClick={(event) => onSelectChapter(chapter.id, getSelectionMode(event))}
                          >
                            <span className="tree-marker" aria-hidden="true">
                              <ChapterIcon />
                            </span>
                          </button>
                        </SceneAppendDropTarget>
                        <InlineEditableText
                          className="tree-input"
                          value={chapter.title}
                          activationMode="double_click"
                          onSingleClick={() => void onSelectChapter(chapter.id, "single")}
                          onCommit={(title) => onRenameChapter(chapter.id, title)}
                        />
                        <button
                          className="row-action-button"
                          onClick={() => onDeleteChapter(chapter.id)}
                          aria-label="Delete chapter"
                          title="Delete chapter"
                        >
                          <TrashIcon />
                        </button>
                      </DraggableBinderRow>

                      {isExpanded ? (
                        <div className="binder-children">
                          <SceneDropZone
                            id={`scene-drop:${chapter.id}:0`}
                            isActive={activeDragItem?.type === "scene"}
                          />
                          {chapterScenes.map((scene, sceneIndex) => (
                            <div key={scene.id}>
                              <DraggableBinderRow
                                id={`scene:${scene.id}`}
                                dragItem={{ type: "scene", id: scene.id }}
                                rowRef={(element) => {
                                  if (element) {
                                    rowRefs.current.set(`scene:${scene.id}`, element);
                                  } else {
                                    rowRefs.current.delete(`scene:${scene.id}`);
                                  }
                                }}
                                className={`binder-scene ${selectedSceneIds.includes(scene.id) || selectedSceneId === scene.id ? "is-selected" : ""}`}
                              >
                                <button
                                  className="scene-hit-area"
                                  onClick={(event) => onSelectScene(scene.id, getSelectionMode(event))}
                                >
                                  <span className="tree-marker" aria-hidden="true">
                                    <SceneIcon />
                                  </span>
                                </button>
                                <InlineEditableText
                                  className="tree-input"
                                  value={scene.title}
                                  activationMode="double_click"
                                  onSingleClick={() => void onSelectScene(scene.id, "single")}
                                  onCommit={(title) => onRenameScene(scene.id, title)}
                                />
                                <button
                                  className="row-action-button"
                                  onClick={() => onDeleteScene(scene.id)}
                                  aria-label="Delete scene"
                                  title="Delete scene"
                                >
                                  <TrashIcon />
                                </button>
                              </DraggableBinderRow>
                              <SceneDropZone
                                id={`scene-drop:${chapter.id}:${sceneIndex + 1}`}
                                isActive={activeDragItem?.type === "scene"}
                              />
                            </div>
                          ))}
                        </div>
                      ) : null}
                    </div>
                  );
                })}
                <ChapterDropZone id="chapter-drop:end" isActive={activeDragItem?.type === "chapter"} />
              </div>
            </div>

            <div className={`binder-trash ${isTrashExpanded ? "is-expanded" : ""}`}>
              <div className="binder-row binder-row-static binder-trash-header">
                <button
                  className="tree-toggle"
                  onClick={() => setIsTrashExpanded((current) => !current)}
                  aria-label={isTrashExpanded ? "Collapse trash" : "Expand trash"}
                >
                  {isTrashExpanded ? "−" : "+"}
                </button>
                <button
                  className="chapter-hit-area"
                  onClick={() => setIsTrashExpanded((current) => !current)}
                  aria-label="Toggle trash"
                >
                  <span className="tree-marker" aria-hidden="true">
                    <TrashIcon />
                  </span>
                </button>
                <div className="binder-trash-title">
                  <strong>Trash</strong>
                  <span>{trashItems.length} item{trashItems.length === 1 ? "" : "s"}</span>
                </div>
              </div>

              {isTrashExpanded ? (
                <div className="binder-children binder-trash-items">
                  {trashItems.length === 0 ? (
                    <div className="binder-trash-empty">Trash is empty.</div>
                  ) : (
                    trashItems.map((trashItem) => {
                      const sceneCount =
                        trashItem.entityType === "chapter"
                          ? ((trashItem.payload as { scenes: SceneRecord[] }).scenes?.length ?? 0)
                          : 1;

                      return (
                        <div
                          key={trashItem.id}
                          className={`binder-row binder-row-static binder-trash-row ${selectedTrashItemId === trashItem.id ? "is-selected" : ""}`}
                        >
                          <div className="binder-trash-item">
                            <button
                              className="binder-trash-preview-button"
                              type="button"
                              onClick={() => onSelectTrashItem(trashItem.id)}
                            >
                              <span className="tree-marker" aria-hidden="true">
                                {trashItem.entityType === "chapter" ? <ChapterIcon /> : <SceneIcon />}
                              </span>
                              <div className="binder-trash-copy">
                                <strong>
                                  {trashItem.entityType === "chapter"
                                    ? `Chapter: ${trashItem.title}`
                                    : `${trashItem.originalParentTitle ?? "Unknown Chapter"} / ${trashItem.title}`}
                                </strong>
                                <span>
                                  {trashItem.entityType === "chapter"
                                    ? `${sceneCount} scene${sceneCount === 1 ? "" : "s"}`
                                    : "Scene"}
                                </span>
                              </div>
                            </button>
                          </div>
                          <div className="binder-trash-actions">
                            <button
                              className="secondary-button binder-trash-action"
                              type="button"
                              onClick={() => onRestoreTrashItem(trashItem.id)}
                            >
                              Restore
                            </button>
                            <button
                              className="row-action-button is-visible"
                              type="button"
                              onClick={() => onPermanentDeleteTrashItem(trashItem.id)}
                              aria-label="Delete permanently"
                              title="Delete permanently"
                            >
                              <TrashIcon />
                            </button>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              ) : null}
            </div>
          </div>
        </div>
        <DragOverlay>
          {activeDragItem ? (
            <div className="binder-drag-overlay">
              {activeDragItem.type === "chapter" ? (
                <span className="tree-marker"><ChapterIcon /></span>
              ) : (
                <span className="tree-marker"><SceneIcon /></span>
              )}
            </div>
          ) : null}
        </DragOverlay>
      </DndContext>
    </aside>
  );
}

function DraggableBinderRow({
  id,
  dragItem,
  className,
  rowRef,
  children
}: {
  id: string;
  dragItem: DragItem;
  className?: string;
  rowRef?: (element: HTMLDivElement | null) => void;
  children: ReactNode;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    isDragging
  } = useDraggable({
    id,
    data: dragItem
  });

  return (
    <div
      ref={(element) => {
        setNodeRef(element);
        rowRef?.(element);
      }}
      className={`binder-row ${className ?? ""} ${isDragging ? "is-dragging" : ""}`}
      style={{
        transform: transform ? `translate3d(${transform.x}px, ${transform.y}px, 0)` : undefined
      }}
      {...attributes}
      {...listeners}
    >
      {children}
    </div>
  );
}

function SceneDropZone({ id, isActive }: { id: string; isActive: boolean }) {
  const { setNodeRef, isOver } = useDroppable({
    id,
    data: {
      type: "scene-drop"
    }
  });

  return (
    <div
      ref={setNodeRef}
      className={`binder-drop-zone scene-drop-zone ${isActive ? "is-visible" : ""} ${isOver ? "is-over" : ""}`}
    />
  );
}

function ChapterDropZone({ id, isActive }: { id: string; isActive: boolean }) {
  const { setNodeRef, isOver } = useDroppable({
    id,
    data: {
      type: "chapter-drop"
    }
  });

  return (
    <div
      ref={setNodeRef}
      className={`binder-drop-zone chapter-drop-zone ${isActive ? "is-visible" : ""} ${isOver ? "is-over" : ""}`}
    />
  );
}

function SceneAppendDropTarget({
  chapterId,
  isActive,
  children
}: {
  chapterId: string;
  isActive: boolean;
  children: ReactNode;
}) {
  const { setNodeRef, isOver } = useDroppable({
    id: `scene-append:${chapterId}`,
    data: {
      type: "scene-append"
    }
  });

  return (
    <div ref={setNodeRef} className={`chapter-scene-drop-target ${isActive ? "is-visible" : ""} ${isOver ? "is-over" : ""}`}>
      {children}
    </div>
  );
}

function BinderIconFrame({ children }: { children: ReactNode }) {
  return <span className="binder-toolbar-icon" aria-hidden="true">{children}</span>;
}

function BinderSvg({ children }: { children: ReactNode }) {
  return (
    <svg
      viewBox="0 0 24 24"
      className="binder-svg-icon"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );
}

function ChapterIcon() {
  return (
    <BinderSvg>
      <path d="M5 6.5A2.5 2.5 0 0 1 7.5 4H19v16H7.5A2.5 2.5 0 0 0 5 22z" />
      <path d="M5 6.5V20" />
      <line x1="9" y1="8" x2="15" y2="8" />
      <line x1="9" y1="12" x2="15" y2="12" />
    </BinderSvg>
  );
}

function SceneIcon() {
  return (
    <BinderSvg>
      <path d="M8 3h6l4 4v14H8z" />
      <path d="M14 3v4h4" />
      <line x1="10" y1="12" x2="16" y2="12" />
      <line x1="10" y1="16" x2="16" y2="16" />
    </BinderSvg>
  );
}

function TrashIcon() {
  return (
    <BinderSvg>
      <path d="M4 7h16" />
      <path d="M9 7V4h6v3" />
      <path d="M7 7l1 13h8l1-13" />
      <line x1="10" y1="11" x2="10" y2="17" />
      <line x1="14" y1="11" x2="14" y2="17" />
    </BinderSvg>
  );
}
