"use client";

import { useEffect, useState, type ReactNode } from "react";
import { Modal } from "@/components/ui/Modal";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Field";
import { Spinner } from "@/components/ui/Spinner";

export function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title,
  description,
  confirmLabel = "Onayla",
  tone = "default",
  requireText,
  loading,
}: {
  open: boolean;
  onClose: () => void;
  onConfirm: () => void | Promise<void>;
  title: string;
  description?: ReactNode;
  confirmLabel?: string;
  tone?: "danger" | "default";
  requireText?: string; // ayarlıysa kullanıcı bu metni yazmadan onay aktif olmaz
  loading?: boolean;
}) {
  const [text, setText] = useState("");

  useEffect(() => {
    if (!open) setText("");
  }, [open]);

  const disabled = Boolean(loading) || (requireText ? text.trim() !== requireText : false);

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
      footer={
        <>
          <Button variant="ghost" onClick={onClose} disabled={loading}>
            Vazgeç
          </Button>
          <Button
            variant={tone === "danger" ? "danger" : "primary"}
            onClick={onConfirm}
            disabled={disabled}
          >
            {loading ? <Spinner className="h-5 w-5" /> : confirmLabel}
          </Button>
        </>
      }
    >
      {description ? <div className="text-sm text-slate-600">{description}</div> : null}
      {requireText ? (
        <div className="mt-4">
          <p className="mb-1.5 text-sm text-slate-600">
            Onaylamak için <span className="font-mono font-semibold">{requireText}</span> yazın:
          </p>
          <Input value={text} onChange={(e) => setText(e.target.value)} />
        </div>
      ) : null}
    </Modal>
  );
}
