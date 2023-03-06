import { AllPublishOptions, BlockMap } from "builder-util-runtime"
import { app } from "electron"
import * as path from "path"
import { AppAdapter } from "./AppAdapter"
import { DownloadUpdateOptions } from "./AppUpdater"
import { BaseUpdater, InstallOptions } from "./BaseUpdater"
import { DifferentialDownloaderOptions } from "./differentialDownloader/DifferentialDownloader"
import { GenericDifferentialDownloader } from "./differentialDownloader/GenericDifferentialDownloader"
import { DOWNLOAD_PROGRESS, ResolvedUpdateFileInfo } from "./main"
import { blockmapFiles } from "./util"
import { findFile, Provider } from "./providers/Provider"
import { URL } from "url"
import { gunzipSync } from "zlib"

export class PkgUpdater extends BaseUpdater {
  constructor(options?: AllPublishOptions | null, app?: AppAdapter) {
    super(options, app)
  }

  /*** @private */
  protected doDownloadUpdate(downloadUpdateOptions: DownloadUpdateOptions): Promise<Array<string>> {
    const provider = downloadUpdateOptions.updateInfoAndProvider.provider
    const fileInfo = findFile(provider.resolveFiles(downloadUpdateOptions.updateInfoAndProvider.info), "pkg")!
    return this.executeDownload({
      fileExtension: "pkg",
      downloadUpdateOptions,
      fileInfo,
      task: async (destinationFile, downloadOptions, packageFile, removeTempDirIfAny) => {
        if (await this.differentialDownloadInstaller(fileInfo, downloadUpdateOptions, destinationFile, provider)) {
          await this.httpExecutor.download(fileInfo.url, destinationFile, downloadOptions)
        }
      },
    })
  }

  protected doInstall(options: InstallOptions): boolean {
    const cmdPath = path.resolve(path.dirname(app.getPath("exe")), "install-update")
    const args = [options.installerPath]
    this.spawnLog(cmdPath, args).catch((e: Error) => {
      // https://github.com/electron-userland/electron-builder/issues/1129
      // Node 8 sends errors: https://nodejs.org/dist/latest-v8.x/docs/api/errors.html#errors_common_system_errors
      const errorCode = (e as NodeJS.ErrnoException).code
      this._logger.info(`Cannot run installer: error code: ${errorCode}, error message: "${e.message}", will be executed again using elevate if EACCES"`)
      this.dispatchError(e)
    })
    return true
  }

  private async differentialDownloadInstaller(
    fileInfo: ResolvedUpdateFileInfo,
    downloadUpdateOptions: DownloadUpdateOptions,
    installerPath: string,
    provider: Provider<any>
  ): Promise<boolean> {
    try {
      if (this._testOnlyOptions != null && !this._testOnlyOptions.isUseDifferentialDownload) {
        return true
      }
      const blockmapFileUrls = blockmapFiles(fileInfo.url, this.app.version, downloadUpdateOptions.updateInfoAndProvider.info.version)
      this._logger.info(`Download block maps (old: "${blockmapFileUrls[0]}", new: ${blockmapFileUrls[1]})`)

      const downloadBlockMap = async (url: URL): Promise<BlockMap> => {
        const data = await this.httpExecutor.downloadToBuffer(url, {
          headers: downloadUpdateOptions.requestHeaders,
          cancellationToken: downloadUpdateOptions.cancellationToken,
        })

        if (data == null || data.length === 0) {
          throw new Error(`Blockmap "${url.href}" is empty`)
        }

        try {
          return JSON.parse(gunzipSync(data).toString())
        } catch (e: any) {
          throw new Error(`Cannot parse blockmap "${url.href}", error: ${e}`)
        }
      }

      const downloadOptions: DifferentialDownloaderOptions = {
        newUrl: fileInfo.url,
        oldFile: path.join(this.downloadedUpdateHelper!.cacheDir, "current.pkg"),
        logger: this._logger,
        newFile: installerPath,
        isUseMultipleRangeRequest: provider.isUseMultipleRangeRequest,
        requestHeaders: downloadUpdateOptions.requestHeaders,
        cancellationToken: downloadUpdateOptions.cancellationToken,
      }

      if (this.listenerCount(DOWNLOAD_PROGRESS) > 0) {
        downloadOptions.onProgress = it => this.emit(DOWNLOAD_PROGRESS, it)
      }

      const blockMapDataList = await Promise.all(blockmapFileUrls.map(u => downloadBlockMap(u)))
      await new GenericDifferentialDownloader(fileInfo.info, this.httpExecutor, downloadOptions).download(blockMapDataList[0], blockMapDataList[1])
      return false
    } catch (e: any) {
      this._logger.error(`Cannot download differentially, fallback to full download: ${e.stack || e}`)
      if (this._testOnlyOptions != null) {
        // test mode
        throw e
      }
      return true
    }
  }
}
