enum LinuxEklentiler {
    static func kur(pencere: LinuxPencere, editor: LinuxEditor, panel: LinuxKenarPaneli) {
        LinuxIcindekiler.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxBulucu.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxMenuler.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxBlokMenusu.kur(pencere: pencere, editor: editor)
        LinuxGorseller.kur(pencere: pencere, editor: editor)
        LinuxTablolar.kur(editor: editor)
        LinuxKodVeUyari.kur(pencere: pencere, editor: editor)
        LinuxKatlama.kur(pencere: pencere, editor: editor)
        LinuxCopKutusu.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxAnaSayfa.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxSayfaSecenekleri.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxGecmis.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxDisaAktar.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxSayfaDosyalari.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxKodGoruntuleyici.kur(pencere: pencere, editor: editor, panel: panel)
        LinuxKisayolPenceresi.kur(pencere: pencere, editor: editor, panel: panel)
    }

    /// Kaydetme/üstbilgi bildiriminde panoları sıfırlama; açma, boşaltma, yol ve mod değişiminde sıfırla.
    static func yasamDongusunuIzle(_ editor: LinuxEditor, _ eylem: @escaping () -> Void) {
        var url = editor.acikURL, etkin = editor.editorEtkin
        editor.durumDegisti.append { [weak editor] in
            guard let editor, editor.acikURL != url || editor.editorEtkin != etkin else { return }
            url = editor.acikURL
            etkin = editor.editorEtkin
            eylem()
        }
    }
}
