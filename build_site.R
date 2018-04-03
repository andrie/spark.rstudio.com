library(pkgdown)
library(dplyr)
library(purrr)
library(stringr)
library(crayon)
library(yaml)
library(fs)


root <-  function() rprojroot::find_rstudio_root_file()

rebuild_site <- function(overwrite = TRUE, skip_reference = FALSE){

  process_content(overwrite = overwrite)
  if(!skip_reference) process_reference(overwrite = overwrite)
  reset_public()

  old <- getwd()
  setwd(file.path(old, target_path()))
  blogdown::build_site(local = TRUE)

  on.exit(setwd(old))
}

copy_repo <- function(github_repo, package_folder = "repos"){
  pr <- str_split(github_repo, "/")
  pr <- pr[[1]][2]
  repo <- path(root(), package_folder, pr)
  if(dir_exists(repo)) dir_delete(repo)
  system(paste0("git clone https://github.com/", github_repo, " -b master ", repo))
}


replace_text <- function(location, lookfor, replacewith){
  read_in_file <- readLines(location)
  new_read_in_file <- gsub(lookfor, replacewith, x = read_in_file, ignore.case = TRUE)
  if(sum(read_in_file != new_read_in_file) > 0)write(new_read_in_file, location)
}

replace_text_folder <- function(path = NULL, type = "Rmd", find, replace){
  file_list <- list.files(path)
  file_list <- file_list[grepl(paste0("\\.", type), file_list)]
  file.path(path, file_list) %>%
    map(~replace_text(location = .x,
                      lookfor = find,
                      replacewith = replace ))
}

copy_content <- function(source, target, overwrite = FALSE){

  # Adds subfolder if non-existent
  if(!file.exists(dirname(target))){
    dir.create(dirname(target))
    cat(green("Adding folder:", dirname(target)), "\n")
  }

  if(!file.info(source)$isdir){
    if(overwrite & file.exists(target)) {
      unlink(target)
      cat(red("Removed file:", target), "\n")
    }
    if(!file.exists(target)) {
      invisible(file.copy(source, target, overwrite = FALSE))
      cat(green("Added file:", target), "\n")
    }
  } else {
    if(overwrite & file.exists(target)) {
      unlink(target, recursive = TRUE, force = TRUE )
      cat(red("Removed folder:", target), "\n")
    }
    if(!file.exists(target)) {
      invisible(file.copy(source, dirname(target), recursive = TRUE, overwrite = FALSE))
      cat(green("Added folder & files:", target), "\n")
    }
  }


}

source_path <- function(path = "", base_path = NULL){
  if(is.null(base_path))base_path <- site_setup()$path[[1]][[1]]
  if(base_path == ""){
    path
  } else {
    file.path(base_path, path)
  }
}

target_path <- function(path = "", base_path = NULL){
  if(is.null(base_path))base_path <- site_setup()$path[[1]][[2]]
  if(base_path == ""){
    path
  } else {
    file.path(base_path, path)
  }
}

reset_folder <- function(path){
  unlink(target_path(path), recursive = TRUE, force = TRUE )
  dir.create(target_path(path))
}

reset_site <- function(){
  reset_folder("content")
  reset_folder("static")
  reset_folder("public")
}

reset_public <- function(){
  unlink(target_path("public"), recursive = TRUE, force = TRUE )
  dir.create(target_path("public"))
}

site_setup <- function() yaml::yaml.load_file("_blogdown.yml")

process_content <- function(overwrite = FALSE, target = NULL){

  site <- site_setup()

  site$site %>%
    walk(~copy_content(
      source_path(.x[[1]]),
      target_path(.x[[2]]),
      overwrite = overwrite
    ))

  if(overwrite){
    site$site %>%
      walk(~unlink(
        paste0(strsplit(target_path(.x[[2]]), split = "\\.")[[1]][1], ".html"),
        force = TRUE
      ))
  }

  site$cleanup %>%
    map(~replace_text_folder(
      path = file.path(target_path(), .x[[1]]),
      type = .x[[2]],
      find = .x[[3]],
      replace = .x[[4]]))

}

site_reference <- function(overwrite = FALSE){
  
  
  if(file_exists(target_path("_pkgdown.yml"))) file_delete(target_path("_pkgdown.yml"))
  
  reference <- yaml.load_file("_blogdown.yml")
  reference$template$path <- path(
    root(),
    reference$template$path
  )
  writeLines(
    as.character(yaml::as.yaml(reference)), 
    "_pkgdown.yml")
  
  copy_content(
    source = source_path("man"),
    target = target_path("man"),
    overwrite = overwrite
  )
  
  copy_content(
    source = source_path("man-roxygen"),
    target = target_path("man-roxygen"),
    overwrite = overwrite
  )
  
  copy_content(
    source = source_path("DESCRIPTION"),
    target = target_path("DESCRIPTION"),
    overwrite = overwrite
  )
  
  
  pkgdown::build_reference(path = target_path("content/reference"))
}

process_reference_old <- function(overwrite = FALSE){

  unlink(file.path(source_path("content/reference"), "*.*"), recursive = TRUE)

  reference <- yaml.load_file("_blogdown.yml")
  reference$template$path <- file.path(
    root(),
    reference$template$path
  )

  if(file.exists(source_path("_pkgdown.yml")))unlink(source_path("_pkgdown.yml"))
  reference <- as.character(yaml::as.yaml(reference))
  writeLines(reference, "_pkgdown.yml")


  if(overwrite)unlink(file.path(source_path("docs/reference"), "*.*"), recursive = TRUE)

  original_wd <- getwd()
  setwd(file.path(original_wd, source_path()))
  pkgdown::build_reference(lazy = !overwrite)
  setwd(original_wd)

  copy_content(
    source_path("docs/reference"),
    target_path("content/reference"),
    overwrite = TRUE
  )

#build cleanup-reference makes changes to the content of the Reference pages only
   site_setup()$`cleanup-reference` %>%
     walk(~replace_text_folder(target_path("content/reference"), .x[[1]], .x[[2]], .x[[3]]))

}


