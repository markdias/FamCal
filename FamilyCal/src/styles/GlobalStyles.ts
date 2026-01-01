import { StyleSheet } from 'react-native';
import { colors, spacing, borderRadius, shadows, typography } from './designTokens';

export const lightThemeStyles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.gray2,
  },
  surface: {
    backgroundColor: colors.gray2,
  },
  card: {
    backgroundColor: colors.gray2,
    borderRadius: borderRadius.m,
    padding: spacing.m,
    ...shadows.medium,
  },
  text: {
    color: colors.gray5,
  },
  textSecondary: {
    color: colors.gray4,
  },
});

export const darkThemeStyles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: colors.darkGray1,
  },
  surface: {
    backgroundColor: colors.darkGray1,
  },
  card: {
    backgroundColor: colors.darkGray2,
    borderRadius: borderRadius.m,
    padding: spacing.m,
    ...shadows.medium,
  },
  text: {
    color: colors.darkGray5,
  },
  textSecondary: {
    color: colors.darkGray4,
  },
});

export const globalStyles = StyleSheet.create({
  container: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
    paddingTop: spacing.xxl,
  },
  scrollContainer: {
    flexGrow: 1,
    padding: spacing.m,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  column: {
    flexDirection: 'column',
  },
  center: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  spaceBetween: {
    justifyContent: 'space-between',
  },
  spaceAround: {
    justifyContent: 'space-around',
  },
  flexStart: {
    justifyContent: 'flex-start',
  },
  flexEnd: {
    justifyContent: 'flex-end',
  },
  stretch: {
    alignItems: 'stretch',
  },
  grow: {
    flexGrow: 1,
  },
  wrap: {
    flexWrap: 'wrap',
  },
  divider: {
    height: 1,
    backgroundColor: colors.gray1,
    marginVertical: spacing.s,
  },
  separator: {
    height: StyleSheet.hairlineWidth,
    backgroundColor: colors.gray1,
    marginLeft: spacing.m,
  },
  icon: {
    width: 24,
    height: 24,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: borderRadius.full,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarSmall: {
    width: 32,
    height: 32,
    borderRadius: borderRadius.full,
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarLarge: {
    width: 56,
    height: 56,
    borderRadius: borderRadius.full,
    justifyContent: 'center',
    alignItems: 'center',
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: borderRadius.full,
  },
  badge: {
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.xxs,
    borderRadius: borderRadius.xs,
    minWidth: 20,
    justifyContent: 'center',
    alignItems: 'center',
  },
});

export { colors, spacing, borderRadius, shadows, typography };
