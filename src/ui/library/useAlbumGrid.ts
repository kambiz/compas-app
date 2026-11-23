import { useWindowDimensions } from 'react-native';
import { Size, Space } from '../tokens';

const MIN_TILE_WIDTH = 176;

export const ALBUM_GRID_GAP = Space.md;

export function useAlbumGrid() {
  const { width: windowWidth } = useWindowDimensions();
  // Tabs sit in a centred column capped at Size.readableWidth, so size tiles to that, not the window.
  const width = Math.min(windowWidth, Size.readableWidth);
  const available = width - Space.lg * 2;
  const columns = Math.max(2, Math.floor((available + ALBUM_GRID_GAP) / (MIN_TILE_WIDTH + ALBUM_GRID_GAP)));
  const tileWidth = Math.floor((available - ALBUM_GRID_GAP * (columns - 1)) / columns);
  return { columns, tileWidth };
}
