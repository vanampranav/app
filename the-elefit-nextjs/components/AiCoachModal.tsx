import React from 'react';
import { X } from 'lucide-react';

interface AiCoachModalProps {
    isOpen: boolean;
    onClose: () => void;
    title: string;
    description: string;
    confirmText: string;
    cancelText: string;
    onConfirm: () => void;
    onCancel: () => void;
    showCloseButton?: boolean;
}

export function AiCoachModal({
    isOpen,
    onClose,
    title,
    description,
    confirmText,
    cancelText,
    onConfirm,
    onCancel,
    showCloseButton = false,
}: AiCoachModalProps) {
    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 z-[60] flex items-end md:items-center justify-center animate-in fade-in duration-300">
            {/* Backdrop */}
            <div
                className="absolute inset-0 bg-black/60 backdrop-blur-sm"
                onClick={onClose}
            />

            {/* Modal Container */}
            <div className={`relative w-full md:max-w-md bg-[#111] rounded-t-[40px] md:rounded-[40px] border-t md:border border-white/10 px-6 pt-2 pb-32 md:pb-12 h-auto shadow-2xl transition-transform duration-500 ease-out animate-in slide-in-from-bottom-full`}>

                {/* Drag Handle Area */}
                <div className="w-full pt-2 pb-6 flex justify-center">
                    <div className="w-12 h-1 bg-white/20 rounded-full" />
                </div>

                {/* Close Button (Optional) */}
                {showCloseButton && (
                    <button
                        onClick={onClose}
                        className="absolute right-6 top-8 text-white/40 hover:text-white transition-colors"
                    >
                        <X className="w-6 h-6" />
                    </button>
                )}

                {/* Content */}
                <div className="relative space-y-8">
                    <div className="space-y-3">
                        <h2 className="text-[22px] font-black text-white tracking-tight leading-tight">{title}</h2>
                        <p className="text-sm font-medium text-white/40 leading-relaxed">
                            {description}
                        </p>
                    </div>

                    <div className="space-y-4 pt-4">
                        <button
                            onClick={onConfirm}
                            className="w-full py-4 bg-primary text-black font-black text-sm rounded-full shadow-[0_4px_15_rgba(204,216,83,0.3)] hover:scale-[1.02] active:scale-[0.98] transition-all"
                        >
                            {confirmText}
                        </button>
                        <button
                            onClick={onCancel}
                            className="w-full py-2 text-primary font-bold text-sm hover:underline transition-all"
                        >
                            {cancelText}
                        </button>
                    </div>
                </div>
            </div>
        </div>
    );
}
