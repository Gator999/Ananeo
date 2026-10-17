/**
 * Converts any picked image to a JPEG no larger than 1600 px on its longest side.
 * Drawing through a canvas also drops EXIF data, so GPS metadata never leaves the device.
 */
export async function preparePhoto(file: File, maxDimension = 1600): Promise<Blob> {
  const bitmap = await createImageBitmap(file).catch(() => null)
  if (!bitmap) throw new Error(`Couldn't read ${file.name}. Try a JPEG or PNG.`)
  const scale = Math.min(1, maxDimension / Math.max(bitmap.width, bitmap.height))
  const width = Math.round(bitmap.width * scale)
  const height = Math.round(bitmap.height * scale)
  const canvas = document.createElement('canvas')
  canvas.width = width
  canvas.height = height
  const context = canvas.getContext('2d')
  if (!context) throw new Error('Image processing is not available in this browser.')
  context.fillStyle = '#fff'
  context.fillRect(0, 0, width, height)
  context.drawImage(bitmap, 0, 0, width, height)
  bitmap.close()
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve(blob) : reject(new Error("Couldn't encode the photo."))), 'image/jpeg', 0.8)
  })
}
