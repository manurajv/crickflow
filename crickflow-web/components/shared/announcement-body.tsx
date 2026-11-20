import type { ReactNode } from "react";
import { parseAnnouncementBody, type RichNode } from "@/lib/rich-text";

function renderNodes(nodes: RichNode[]): ReactNode[] {
  return nodes.map((node, index) => renderNode(node, index));
}

function renderNode(node: RichNode, index: number): ReactNode {
  switch (node.type) {
    case "text":
      return <span key={index}>{node.text}</span>;
    case "strong":
      return <strong key={index}>{renderNodes(node.children)}</strong>;
    case "em":
      return <em key={index}>{renderNodes(node.children)}</em>;
    case "link":
      return (
        <a
          key={index}
          href={node.href}
          target="_blank"
          rel="noopener noreferrer"
          className="text-primary underline"
        >
          {renderNodes(node.children)}
        </a>
      );
    case "p":
      return (
        <p key={index} className="whitespace-pre-wrap">
          {renderNodes(node.children)}
        </p>
      );
    case "li":
      return <li key={index}>{renderNodes(node.children)}</li>;
    case "ul":
      return (
        <ul key={index} className="list-disc space-y-1 pl-5">
          {renderNodes(node.children)}
        </ul>
      );
    case "ol":
      return (
        <ol key={index} className="list-decimal space-y-1 pl-5">
          {renderNodes(node.children)}
        </ol>
      );
    default:
      return null;
  }
}

export function AnnouncementBody({ body }: { body: string }) {
  const nodes = parseAnnouncementBody(body);
  if (!nodes.length) return null;
  return <div className="space-y-2 text-sm">{renderNodes(nodes)}</div>;
}
