function saveCurrency() {
    $lastComment = base64_encode($_POST['closeComment']);
    $codUsr = $_POST['codUsr'];
    $sub_group_code = isset($_POST['sub_group_code']) ? trim($_POST['sub_group_code']) : trim($_POST['ls_code']);
    $txtrate = isset($_POST['txtrate']) ? $_POST['txtrate'] : 0;
    $curr = $_POST['newcurrency'];
    $creditfile_type = $_POST['codtype_cdt'];
    $cod_withlimit = $_POST['codtype_withlimit'];
    $CF_Level = $_POST['CF_Level'];

    if ($sub_group_code != '') {
        if ($creditfile_type == '26') {
            // Run SPU_TSPMCURDBE first
            $query_Line = "SELECT * FROM dbo.\"SPU_TSPMCURDBE\"(
                '".$sub_group_code."', 
                '".$curr."', 
                ".$txtrate.", 
                ".$codUsr.",
                '".$lastComment."',
                '".$CF_Level."', 
                ".$creditfile_type.",
                ".$cod_withlimit."
            )";
            $result_Line = pg_query($query_Line);
            
            // Run SPU_LIMITS_TLINERIADBE only if with_limits is 1
            if ($cod_withlimit == '1') {
                $query_Line2 = "SELECT * FROM dbo.\"SPU_LIMITS_TLINERIADBE\"(
                    '".$sub_group_code."', 
                    ".$creditfile_type.", 
                    ".$codUsr.",
                    ".$cod_withlimit."
                )";
                $result_Line2 = pg_query($query_Line2);
                
                if ($result_Line && $result_Line2) {
                    echo '{"id": "success"}';
                } else {
                    echo '{"id": "fail"}';
                }
            } else {
                if ($result_Line) {
                    echo '{"id": "success"}';
                } else {
                    echo '{"id": "fail"}';
                }
            }
        } else if ($creditfile_type == '25') {
            // Similar logic for credit file type 25
            $query_Line = "SELECT * FROM dbo.\"SPU_TSPMCURDBE\"(
                '".$sub_group_code."', 
                '".$curr."', 
                ".$txtrate.", 
                ".$codUsr.",
                '".$lastComment."',
                '".$CF_Level."', 
                ".$creditfile_type.",
                ".$cod_withlimit."
            )";
            $result_Line = pg_query($query_Line);
            
            if ($cod_withlimit == '1') {
                $query_Line2 = "SELECT * FROM dbo.\"SPU_LIMITS_TLINERIADBE\"(
                    '".$sub_group_code."', 
                    ".$creditfile_type.", 
                    ".$codUsr.",
                    ".$cod_withlimit."
                )";
                $result_Line2 = pg_query($query_Line2);
                
                if ($result_Line && $result_Line2) {
                    echo '{"id": "success"}';
                } else {
                    echo '{"id": "fail"}';
                }
            } else {
                if ($result_Line) {
                    echo '{"id": "success"}';
                } else {
                    echo '{"id": "fail"}';
                }
            }
        }
    } else {
        echo '{"id": "fail"}';
    }
}
