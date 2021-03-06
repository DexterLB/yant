let fragment = new URLSearchParams(window.location.hash.substr(1));
let theme = fragment.get('theme');

// do nothing with theme yet. todo.
require('./styles/main.scss');

let elm = require('./Main.elm')

require('./maths.ts')
require('./attached_images.ts')
require('./fonts.ts')

import * as sjcl        from 'sjcl';
import * as storage     from './storage.ts';

type ElmApp = any   // he he

interface Context {
    app: ElmApp
}

function init(app: ElmApp): Context {
    return {
        app: app,
    }
}

interface GetCardRequest {
    mode: "silent_fail" | "default_empty" | "explicit_fail";
    id: string,
}
async function process_get_card(ctx: Context, req: GetCardRequest) {
    let cardID = req.id
    let card = await storage.getCard(cardID)

    if (card == null) {
        if (req.mode == 'default_empty' || cardID == 'root') {
            console.log("returning empty card at ", cardID)
            ctx.app.ports.gotCard.send({
                id: cardID,
                content: {
                    text: "",
                    done: false,
                },
                children: [],
            })
        } else {
            console.log("card missing ", cardID)
            if (req.mode == 'explicit_fail') {
                ctx.app.ports.missingCard.send(cardID)
            }
        }
    } else {
        console.log("returning card at ", cardID, ": ", card)
        ctx.app.ports.gotCard.send(card)
    }
}

async function process_save_card(ctx: Context, card: any) {
    if (!card.id) {
        throw new Error("invalid card id - " + card.id)
    }

    console.log("saving card at ", card.id, " : ", card)

    await storage.saveCard(card)
}

async function process_save_settings(ctx: Context, settings: any) {
    console.log("saving settings: ", settings)

    await storage.saveSettings(settings)
}

function read_file(file: File): Promise<string> {
    let reader = new FileReader()
    let result = new Promise<string>((ok, err) => {
        reader.onload = () => {
            ok(reader.result as string)
        }
        reader.onerror = err
    })

    reader.readAsDataURL(file)
    return result
}

async function process_file_for_attach(ctx: Context, file: File) {
    // todo: this is very suboptimal; find a way to properly store the blob

    let data_url = await read_file(file)
    let data_bits = sjcl.codec.base64.toBits(data_url.split(',')[1])
    let hash = sjcl.codec.base64.fromBits(sjcl.hash.sha256.hash(data_bits)).substring(0, 32)

    await storage.saveFile(hash, data_url)

    let af: storage.AttachedFile = {
        name: file.name,
        hash: hash,
        mime_type: file.type,
    }

    ctx.app.ports.attachedFile.send(af)
}

async function process_attach_file(ctx: Context) {
    let file_input = document.createElement('input') as HTMLInputElement;
    file_input.type = 'file';

    file_input.onchange = e => {
        let target = e.target as HTMLInputElement;
        if (!target.files) {
            return
        }

        for (let file of target.files) {
            process_file_for_attach(ctx, file).catch(err => {
                console.log('unable to process attachment file: ', err)
            })
        }
    }

    file_input.click()
}

async function process_download_attached_file(ctx: Context, af: storage.AttachedFile) {
    let data_url = await storage.getFile(af.hash)
    if (data_url == null) {
        console.log('attached file ', af, ' is missing!')
        return
    }

    let download_el = document.createElement('a') as HTMLAnchorElement
    download_el.href = data_url
    download_el.download = af.name
    download_el.click()
}

async function process_import_data(ctx: Context) {
    await storage.importData()
    ctx.app.ports.reload.send(null)
}

async function process_export_data(ctx: Context) {
    await storage.exportData()
}

async function process_nuke_data(ctx: Context) {
    await storage.nukeAllData()
    ctx.app.ports.reload.send(null)
}

async function main() {
    let flags = {
        settings: await storage.getSettings(),
    }

    let app = elm.Elm.Main.init({ node: document.documentElement, flags: flags });

    let ctx = init(app)

    app.ports.getCard.subscribe((req: any) => {
        process_get_card(ctx, req as GetCardRequest).then(() => {
        }).catch(err => {
            console.log('error while processing get_card request', req, ': ', err)
        })
    });
    app.ports.saveCard.subscribe((card: any) => {
        process_save_card(ctx, card).then(() => {
        }).catch(err => {
            console.log('error while processing save_card request for ', card, ': ', err)
        })
    });
    app.ports.saveSettings.subscribe((settings: any) => {
        process_save_settings(ctx, settings).then(() => {
        }).catch(err => {
            console.log('error while processing save_settings request for ', settings, ': ', err)
        })
    });
    app.ports.attachFile.subscribe(() => {
        process_attach_file(ctx).then(() => {
        }).catch(err => {
            console.log('error while processing save_card request: ', err)
        })
    });
    app.ports.downloadAttachedFile.subscribe((af: storage.AttachedFile) => {
        process_download_attached_file(ctx, af).then(() => {
        }).catch(err => {
            console.log('error while processing download_attached_file request fore ', af, ': ', err)
        })
    });
    app.ports.exportData.subscribe(() => {
        process_export_data(ctx).then(() => {
        }).catch(err => {
            console.log('error while processing export_data request: ', err)
        })
    });
    app.ports.importData.subscribe(() => {
        process_import_data(ctx).then(() => {
        }).catch(err => {
            console.log('error while processing import_data request: ', err)
        })
    });
    app.ports.nukeData.subscribe(() => {
        process_nuke_data(ctx).then(() => {
        }).catch(err => {
            console.log('error while processing nuke_data request: ', err)
        })
    });
}

main()
