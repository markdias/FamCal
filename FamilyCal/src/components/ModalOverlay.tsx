import React, { useEffect, useCallback } from 'react';
import {
  Modal,
  View,
  StyleSheet,
  TouchableWithoutFeedback,
  Animated,
  Dimensions,
} from 'react-native';
import { useTheme } from '@/context/ThemeContext';
import { spacing, borderRadius, shadows } from '@/styles/designTokens';

interface ModalOverlayProps {
  visible: boolean;
  onClose: () => void;
  children: React.ReactNode;
  presentationStyle?: 'fullScreen' | 'pageSheet' | 'overFullScreen';
  animationType?: 'slide' | 'fade' | 'none';
}

export default function ModalOverlay({
  visible,
  onClose,
  children,
  presentationStyle = 'pageSheet',
  animationType = 'slide',
}: ModalOverlayProps) {
  const { colors } = useTheme();

  return (
    <Modal
      visible={visible}
      onRequestClose={onClose}
      presentationStyle={presentationStyle}
      animationType={animationType}
      transparent={presentationStyle === 'overFullScreen'}
    >
      {presentationStyle === 'overFullScreen' ? (
        <TouchableWithoutFeedback onPress={onClose}>
          <View style={styles.overlay}>
            <TouchableWithoutFeedback onPress={() => {}}>
              <View style={[styles.modalContent, { backgroundColor: colors.card }]}>
                {children}
              </View>
            </TouchableWithoutFeedback>
          </View>
        </TouchableWithoutFeedback>
      ) : (
        children
      )}
    </Modal>
  );
}

// Bottom sheet style modal
interface BottomSheetModalProps {
  visible: boolean;
  onClose: () => void;
  children: React.ReactNode;
  snapPoints?: string[];
}

export function BottomSheetModal({
  visible,
  onClose,
  children,
  snapPoints = ['50%', '80%'],
}: BottomSheetModalProps) {
  const { colors } = useTheme();

  return (
    <Modal
      visible={visible}
      onRequestClose={onClose}
      presentationStyle="pageSheet"
      animationType="slide"
    >
      <View style={[styles.container, { backgroundColor: colors.background }]}>
        {/* Handle bar */}
        <View style={styles.handleContainer}>
          <View style={[styles.handle, { backgroundColor: colors.border }]} />
        </View>
        {children}
      </View>
    </Modal>
  );
}

// Confirmation dialog
interface ConfirmDialogProps {
  visible: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  isDestructive?: boolean;
}

export function ConfirmDialog({
  visible,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = 'Confirm',
  cancelText = 'Cancel',
  isDestructive = false,
}: ConfirmDialogProps) {
  const { colors } = useTheme();

  return (
    <ModalOverlay visible={visible} onClose={onClose}>
      <View style={styles.dialogContainer}>
        <Text style={[styles.dialogTitle, { color: colors.text }]}>{title}</Text>
        <Text style={[styles.dialogMessage, { color: colors.textSecondary }]}>
          {message}
        </Text>
        
        <View style={styles.dialogActions}>
          <TouchableWithoutFeedback onPress={onClose}>
            <View style={[styles.dialogButton, styles.dialogCancel]}>
              <Text style={[styles.dialogButtonText, { color: colors.text }]}>
                {cancelText}
              </Text>
            </View>
          </TouchableWithoutFeedback>
          <TouchableWithoutFeedback onPress={onConfirm}>
            <View
              style={[
                styles.dialogButton,
                styles.dialogConfirm,
                isDestructive && styles.destructiveButton,
              ]}
            >
              <Text
                style={[
                  styles.dialogButtonText,
                  { color: isDestructive ? '#FF3B30' : '#007AFF' },
                ]}
              >
                {confirmText}
              </Text>
            </View>
          </TouchableWithoutFeedback>
        </View>
      </View>
    </ModalOverlay>
  );
}

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    borderRadius: borderRadius.l,
    padding: spacing.l,
    width: '80%',
    maxWidth: 400,
  },
  container: {
    flex: 1,
    paddingTop: spacing.s,
  },
  handleContainer: {
    alignItems: 'center',
    paddingVertical: spacing.s,
  },
  handle: {
    width: 40,
    height: 4,
    borderRadius: 2,
  },
  dialogContainer: {
    padding: spacing.l,
  },
  dialogTitle: {
    fontSize: 20,
    fontWeight: '600',
    marginBottom: spacing.s,
  },
  dialogMessage: {
    fontSize: 15,
    marginBottom: spacing.l,
    lineHeight: 21,
  },
  dialogActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.m,
  },
  dialogButton: {
    paddingVertical: spacing.s,
    paddingHorizontal: spacing.m,
    borderRadius: borderRadius.m,
  },
  dialogCancel: {
    backgroundColor: '#E5E5EA',
  },
  dialogConfirm: {
    backgroundColor: '#E5E5EA',
  },
  destructiveButton: {
    backgroundColor: '#FFE5E5',
  },
  dialogButtonText: {
    fontSize: 17,
    fontWeight: '600',
  },
});
