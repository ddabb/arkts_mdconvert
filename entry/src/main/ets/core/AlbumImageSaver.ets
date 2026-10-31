import { fileIo, fileUri } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { common } from '@kit.AbilityKit';

export class AlbumImageSaver {
  static async savePngBytesToAlbum(ctx: common.Context, bytes: Uint8Array, prefix: string): Promise<boolean> {
    const dir: string = ctx.cacheDir;
    const name: string = prefix + '_' + Date.now().toString(36) + '.png';
    const tmpPath: string = dir + '/' + name;
    const tmp: fileIo.File = fileIo.openSync(tmpPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(tmp.fd, bytes.buffer);
    fileIo.closeSync(tmp);
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(ctx);
    const srcUris: Array<string> = [fileUri.getUriFromPath(tmpPath)];
    const configs: Array<photoAccessHelper.PhotoCreationConfig> = [{
      fileNameExtension: 'png',
      photoType: photoAccessHelper.PhotoType.IMAGE
    }];
    const desUris: Array<string> = await helper.showAssetsCreationDialog(srcUris, configs);
    if (desUris.length == 0) {
      return false;
    }
    const src: fileIo.File = fileIo.openSync(tmpPath, fileIo.OpenMode.READ_ONLY);
    try {
      const des: fileIo.File = await fileIo.open(desUris[0], fileIo.OpenMode.READ_WRITE);
      try {
        await fileIo.copyFile(src.fd, des.fd);
      } finally {
        await fileIo.close(des);
      }
    } finally {
      fileIo.closeSync(src);
    }
    return true;
  }
}
